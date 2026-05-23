locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../terraform/modules/helm"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_endpoint = "https://mock-endpoint.eks.amazonaws.com"
    cluster_ca_data  = "bW9jaw=="
    cluster_name     = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "ecr" {
  config_path = "../ecr"

  mock_outputs = {
    repository_url = "123456789012.dkr.ecr.ap-southeast-7.amazonaws.com/dev-helloworld"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env                  = local.env_vars.locals.env
  cluster_endpoint     = dependency.eks.outputs.cluster_endpoint
  cluster_ca_data      = dependency.eks.outputs.cluster_ca_data
  cluster_name         = local.env_vars.locals.cluster_name
  ecr_repo             = dependency.ecr.outputs.repository_url
  helloworld_image_tag = local.env_vars.locals.helloworld_image_tag
  helloworld_replicas  = local.env_vars.locals.helloworld_replicas
  argocd_version       = local.env_vars.locals.argocd_version
}
