locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../terraform/modules/ecr"
}

inputs = {
  env                  = local.env_vars.locals.env
  repo_name            = local.env_vars.locals.ecr_repo_name
  image_tag_mutability = local.env_vars.locals.ecr_image_tag_mutability
}
