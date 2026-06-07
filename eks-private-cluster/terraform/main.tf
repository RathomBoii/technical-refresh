provider "aws" {
  region = var.region
}

# Helm provider authenticates via EKS cluster token — depends on cluster existing first
# provider "helm" {
#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
#     exec {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       command     = "aws"
#       args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
#     }
#   }
# }

module "vpc" {
  source          = "./modules/vpc"
  env             = var.env
  cluster_name    = var.cluster_name
  vpc_cidr        = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  region          = var.region
  is_single_nat_gateway = var.is_single_nat_gateway
}

module "eks" {
  source                    = "./modules/eks"
  env                       = var.env
  cluster_name              = var.cluster_name
  kubernetes_version        = var.kubernetes_version
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  node_instance_type        = var.node_instance_type
  desired_nodes             = var.desired_nodes
  min_nodes                 = var.min_nodes
  max_nodes                 = var.max_nodes
  bastion_security_group_id = module.bastion.security_group_id
  bastion_role_arn          = module.bastion.role_arn
  admin_principal_arns      = var.admin_principal_arns
}

module "bastion" {
  source            = "./modules/bastion"
  env               = var.env
  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnet_ids[0]
  cluster_name      = var.cluster_name
  region            = var.region
  instance_type     = var.bastion_instance_type
  tfstate_bucket    = var.tfstate_bucket
}

module "ecr" {
  source               = "./modules/ecr"
  env                  = var.env
  repo_name            = var.ecr_repo_name
  image_tag_mutability = var.ecr_image_tag_mutability
}

module "rds" {
  source = "./modules/rds"

  env                        = var.env
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id

  db_identifier           = var.rds_db_identifier
  db_name                 = var.rds_db_name
  db_username             = var.rds_db_username
  instance_class          = var.rds_instance_class
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  skip_final_snapshot     = var.rds_skip_final_snapshot
  deletion_protection     = var.rds_deletion_protection
}

module "secrets" {
  source                   = "./modules/secrets"

  env                      = var.env
  helloworld_api_key_value = var.helloworld_api_key_value
}

module "iam" {
  source = "./modules/iam"

  env               = var.env
  region            = var.region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider

  helloworld_namespace           = var.helloworld_namespace
  helloworld_api_key_secret_name = module.secrets.helloworld_api_key_secret_name

  eso_namespace            = var.eso_namespace
  eso_service_account_name = var.eso_service_account_name

  github_org                  = var.github_org
  github_repo                 = var.github_repo
  ecr_repo_name               = var.ecr_repo_name
  create_github_oidc_provider = var.create_github_oidc_provider
}


