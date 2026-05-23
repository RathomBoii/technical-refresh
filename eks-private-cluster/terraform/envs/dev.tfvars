# ── Dev Environment ───────────────────────────────────────────────────────────
env    = "dev"
region = "ap-southeast-7"

# Cluster
cluster_name = "eks-dev"

# Network
vpc_cidr              = "10.4.0.0/16"
is_single_nat_gateway = true # Cost-saving for dev; set false in prod for HA
private_subnets       = ["10.4.1.0/24", "10.4.2.0/24"]
public_subnets        = ["10.4.0.0/24", "10.4.3.0/24"]

# Node group — small for dev
node_instance_type = "t3.large"
desired_nodes      = 2
min_nodes          = 1
max_nodes          = 3

# EKS Admin Access — add IAM user/role ARNs that need kubectl access
admin_principal_arns = [
  "arn:aws:iam::<AWS_ACCOUNT_ID>:role/<EKS_ADMIN_ROLE_NAME>",
]

# ECR
ecr_repo_name            = "helloworld"
ecr_image_tag_mutability = "MUTABLE"

# Terraform state bucket — required for bastion to run terraform apply
tfstate_bucket = "<TFSTATE_BUCKET_NAME>"

# App
helloworld_image_tag = "latest"
helloworld_replicas  = 1
argocd_version       = "6.7.0"
