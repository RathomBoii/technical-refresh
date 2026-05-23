locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../terraform/modules/bastion"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env               = local.env_vars.locals.env
  vpc_id            = dependency.vpc.outputs.vpc_id
  private_subnet_id = dependency.vpc.outputs.private_subnet_ids[0]
  cluster_name      = local.env_vars.locals.cluster_name
  region            = local.env_vars.locals.region
  tfstate_bucket    = local.env_vars.locals.tfstate_bucket
}
