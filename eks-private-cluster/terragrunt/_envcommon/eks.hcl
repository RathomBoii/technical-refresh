locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../terraform/modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "bastion" {
  config_path = "../bastion"

  mock_outputs = {
    security_group_id = "sg-00000000000000000"
    role_arn          = "arn:aws:iam::123456789012:role/mock-bastion-role"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env                       = local.env_vars.locals.env
  cluster_name              = local.env_vars.locals.cluster_name
  vpc_id                    = dependency.vpc.outputs.vpc_id
  private_subnet_ids        = dependency.vpc.outputs.private_subnet_ids
  node_instance_type        = local.env_vars.locals.node_instance_type
  desired_nodes             = local.env_vars.locals.desired_nodes
  min_nodes                 = local.env_vars.locals.min_nodes
  max_nodes                 = local.env_vars.locals.max_nodes
  bastion_security_group_id = dependency.bastion.outputs.security_group_id
  bastion_role_arn          = dependency.bastion.outputs.role_arn
  admin_principal_arns      = local.env_vars.locals.admin_principal_arns
}
