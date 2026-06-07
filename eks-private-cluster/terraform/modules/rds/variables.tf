variable "env" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "EKS node security group ID — allows pgadmin pod to reach RDS on port 5432"
  type        = string
}

variable "db_identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
  default     = "postgres"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master database username"
  type        = string
  default     = "pgadmin"
}

variable "instance_class" {
  description = "RDS instance class. db.t3.micro is the smallest available for PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "Enable Multi-AZ for high availability. Use false in dev, true in prod"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (0 disables backups)"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy. Set false in prod to protect data"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental deletion via Terraform. Enable in prod"
  type        = bool
  default     = false
}
