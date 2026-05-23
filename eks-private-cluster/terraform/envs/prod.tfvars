# ── Prod Environment ──────────────────────────────────────────────────────────
env    = "prod"
region = "ap-southeast-7"

# Cluster
cluster_name = "eks-prod"

# Network — different CIDR from dev to avoid overlap
vpc_cidr              = "10.5.0.0/16"
is_single_nat_gateway = false # HA for prod; set true in dev for cost-saving
private_subnets       = ["10.5.1.0/24", "10.5.2.0/24"]
public_subnets        = ["10.5.0.0/24", "10.5.3.0/24"]

# Node group — larger for prod
node_instance_type = "t3.large"
desired_nodes      = 3
min_nodes          = 2
max_nodes          = 10

# EKS Admin Access — add IAM user/role ARNs that need kubectl access
admin_principal_arns = [
  "arn:aws:iam::<AWS_ACCOUNT_ID>:role/<EKS_ADMIN_ROLE_NAME>",
]

# ECR
ecr_repo_name            = "helloworld"
ecr_image_tag_mutability = "IMMUTABLE"

# Terraform state bucket — required for bastion to run terraform apply
tfstate_bucket = "<TFSTATE_BUCKET_NAME>"

# App
helloworld_image_tag = "1.0.0"
helloworld_replicas  = 3
argocd_version       = "6.7.0"
