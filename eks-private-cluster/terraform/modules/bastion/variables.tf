variable "env"                { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_id"  { type = string }
variable "cluster_name"       { type = string }
variable "region"             { type = string }
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for the bastion host"
}
variable "tfstate_bucket" { 
    type = string
    description = "S3 bucket name used for Terraform state — grants bastion read/write access for running terraform apply"
}
variable "kubernetes_version" { 
  type = string  
  default = "1.35" 
  description = "Kubernetes version for the EKS cluster"
}