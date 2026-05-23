locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../terraform/modules/vpc"
}

inputs = {
  env                   = local.env_vars.locals.env
  cluster_name          = local.env_vars.locals.cluster_name
  vpc_cidr              = local.env_vars.locals.vpc_cidr
  private_subnets       = local.env_vars.locals.private_subnets
  public_subnets        = local.env_vars.locals.public_subnets
  region                = local.env_vars.locals.region
  is_single_nat_gateway = local.env_vars.locals.is_single_nat_gateway
}
