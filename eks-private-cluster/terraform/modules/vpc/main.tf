# Automatically select the correct number of AZs based on how many subnets are provided
# dev.tfvars = 2 subnets → 2 AZs, prod.tfvars = 3 subnets → 3 AZs
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name            = "${var.cluster_name}-vpc"
  cidr            = var.vpc_cidr
  azs             = slice(data.aws_availability_zones.available.names, 0, length(var.private_subnets))
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = var.is_single_nat_gateway # dev: cost-saving; set false in prod for HA
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags so EKS can discover subnets automatically
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ── VPC Endpoints for ECR (allows private nodes to pull images without NAT) ──

# Security group for interface endpoints — allow HTTPS from within the VPC
resource "aws_security_group" "vpc_endpoints" {
  name   = "${var.cluster_name}-vpc-endpoints"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# S3 Gateway endpoint — ECR stores image layers in S3 (free, no hourly charge)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name      = "${var.cluster_name}-s3-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ECR API Interface endpoint — for authentication and manifest requests
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "${var.cluster_name}-ecr-api-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ECR Docker Interface endpoint — for image layer pulls
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "${var.cluster_name}-ecr-dkr-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# STS Interface endpoint — required for IRSA / Pod Identity token exchange
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "${var.cluster_name}-sts-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# Secrets Manager Interface endpoint — required for ESO and helloworld pods
# running in private subnets to fetch secrets without routing through NAT.
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "${var.cluster_name}-secretsmanager-endpoint"
    Env       = var.env
    ManagedBy = "terraform"
  }
}

# ── VPC Flow Logs (CloudWatch) — required for network audit trail in production ──

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.cluster_name}/flow-logs"
  retention_in_days = 90

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.cluster_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })

  tags = {
    Env       = var.env
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.cluster_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

# AWS VPC Flow log service need the IAM role to have permissions to write logs to CloudWatch, 
# and the log group needs to exist before creating the flow log.
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = module.vpc.vpc_id

  tags = {
    Name      = "${var.cluster_name}-vpc-flow-logs"
    Env       = var.env
    ManagedBy = "terraform"
  }
}
