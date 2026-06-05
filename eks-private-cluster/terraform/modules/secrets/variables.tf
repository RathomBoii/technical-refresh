variable "env" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "helloworld_api_key_value" {
  description = "Initial value for helloworld API key secret. Pass via TF_VAR_helloworld_api_key_value — never commit the real value to tfvars."
  type        = string
  sensitive   = true
}
