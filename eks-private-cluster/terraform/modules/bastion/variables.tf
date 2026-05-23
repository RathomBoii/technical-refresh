variable "env"                { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_id"  { type = string }
variable "cluster_name"       { type = string }
variable "region"             { type = string }
variable "tfstate_bucket"     { 
    type = string
    description = "S3 bucket name used for Terraform state — grants bastion read/write access for running terraform apply"
}
