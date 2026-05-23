provider "aws" {
  region = var.region
}

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
  tfstate_bucket    = var.tfstate_bucket
}

module "ecr" {
  source               = "./modules/ecr"
  env                  = var.env
  repo_name            = var.ecr_repo_name
  image_tag_mutability = var.ecr_image_tag_mutability
}


