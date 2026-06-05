variable "env" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-7"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster (e.g. 1.35)"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "is_single_nat_gateway" {
  description = "Whether to use a single NAT gateway"
  type        = bool
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
}

variable "desired_nodes" {
  description = "Desired number of EKS nodes"
  type        = number
}

variable "min_nodes" {
  description = "Minimum number of EKS nodes"
  type        = number
}

variable "max_nodes" {
  description = "Maximum number of EKS nodes"
  type        = number
}

variable "admin_principal_arns" {
  description = "List of IAM user/role ARNs to grant EKS cluster admin access"
  type        = list(string)
  default     = []
}

variable "ecr_repo_name" {
  description = "ECR repository name for helloworld app"
  type        = string
  default     = "helloworld"
}

variable "ecr_image_tag_mutability" {
  description = "ECR image tag mutability (MUTABLE or IMMUTABLE). Use IMMUTABLE in prod to prevent tag overwriting."
  type        = string
  default     = "IMMUTABLE"
}

variable "helloworld_image_tag" {
  description = "Docker image tag for helloworld app"
  type        = string
  default     = "latest"
}

variable "helloworld_replicas" {
  description = "Number of helloworld pod replicas"
  type        = number
  default     = 1
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "6.7.0"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "tfstate_bucket" {
  description = "S3 bucket name used for Terraform state — grants bastion IAM role access to run terraform apply from inside the VPC"
  type        = string
}

# ── RDS ───────────────────────────────────────────────────────────────────────
variable "rds_db_identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
  default     = "postgres"
}

variable "rds_db_name" {
  description = "Initial database name created inside the RDS instance"
  type        = string
  default     = "appdb"
}

variable "rds_db_username" {
  description = "Master database username"
  type        = string
  default     = "pgadmin"
}

variable "rds_instance_class" {
  description = "RDS instance class. db.t3.micro is the smallest for PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for high availability. false in dev, true in prod"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Days to retain automated backups (0 disables backups)"
  type        = number
  default     = 7
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on destroy. Set false in prod"
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Prevent accidental deletion. Enable in prod"
  type        = bool
  default     = false
}

# ── IAM / App secrets ─────────────────────────────────────────────────────────
variable "helloworld_namespace" {
  description = "Kubernetes namespace where helloworld is deployed"
  type        = string
  default     = "dev-app"
}

variable "helloworld_api_key_value" {
  description = "Initial value for helloworld API key secret in Secrets Manager. Pass via TF_VAR_helloworld_api_key_value env var — never commit to tfvars."
  type        = string
  sensitive   = true
  default     = "changeme-replace-before-use"
}

variable "eso_namespace" {
  description = "Kubernetes namespace where External Secrets Operator is deployed — must match ArgoCD destination namespace"
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account_name" {
  description = "ServiceAccount name used by ESO — must match secret-store chart values.serviceAccount.name"
  type        = string
  default     = "eks-secret-store-irsa"
}