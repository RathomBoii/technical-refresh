# ── Random password — no credentials in source control ────────────────────────
resource "random_password" "db" {
  length  = 16
  special = false # Avoid special chars that can break JDBC connection strings
}

# ── Store password in Secrets Manager — pgadmin reads from here ───────────────
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "/${var.env}/rds/${var.db_identifier}/password"
  recovery_window_in_days = 0 # Force immediate deletion — avoids "scheduled for deletion" error on re-apply

  tags = {
    Name = "${var.env}-rds-password"
    Env  = var.env
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

# ── DB subnet group — RDS stays in private subnets only ───────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${var.env}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.env}-rds-subnet-group"
    Env  = var.env
  }
}

# ── Security group — only EKS nodes (pgadmin pod) can reach port 5432 ─────────
resource "aws_security_group" "rds" {
  name        = "${var.env}-rds-sg"
  description = "Allow PostgreSQL access from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "PostgreSQL from EKS nodes (pgadmin pod)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound (required for RDS maintenance)"
  }

  tags = {
    Name = "${var.env}-rds-sg"
    Env  = var.env
  }
}

# ── RDS PostgreSQL instance ────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier     = var.db_identifier
  engine         = "postgres"
  engine_version = "16.1" # Check available versions: aws rds describe-db-engine-versions --engine postgres --region ap-southeast-7 --query 'DBEngineVersions[*].EngineVersion'
  instance_class = var.instance_class

  allocated_storage     = 20    # Minimum allowed by AWS
  max_allocated_storage = 50   # Auto-scaling cap — prevents surprise bills
  storage_type          = "gp2"
  storage_encrypted     = true  # Encryption at rest — required for any PII data

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false # Private only — no direct internet access
  multi_az            = var.multi_az

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00" # UTC — low-traffic window
  maintenance_window      = "Mon:04:00-Mon:05:00"

  skip_final_snapshot      = var.skip_final_snapshot
  # Required by AWS when skip_final_snapshot = false (prod).
  # Ignored when skip_final_snapshot = true (dev).
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.db_identifier}-final-snapshot"
  deletion_protection       = var.deletion_protection

  # Keep parameter group at default for simplest setup
  # Override here if you need custom postgres.conf settings

  tags = {
    Name = var.db_identifier
    Env  = var.env
  }
}
