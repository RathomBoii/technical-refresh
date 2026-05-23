# ── Root Terragrunt Config ────────────────────────────────────────────────────
# Inherited by all child modules via find_in_parent_folders()

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env            = local.env_vars.locals.env
  region         = local.env_vars.locals.region
  account_id     = local.env_vars.locals.account_id
  tfstate_bucket = local.env_vars.locals.tfstate_bucket
}

# Auto-generate S3 backend — state is isolated per env and module
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = local.tfstate_bucket
    key            = "${local.env}/${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Auto-generate AWS provider
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
}
EOF
}
