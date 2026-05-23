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
  description = "ECR image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
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

variable "tfstate_bucket" {
  description = "S3 bucket name used for Terraform state — grants bastion IAM role access to run terraform apply from inside the VPC"
  type        = string
}
