variable "env"                       { type = string }
variable "cluster_name"              { type = string }
variable "vpc_id"                    { type = string }
variable "private_subnet_ids"        { type = list(string) }
variable "node_instance_type"        { type = string }
variable "desired_nodes"             { type = number }
variable "min_nodes"                 { type = number }
variable "max_nodes"                 { type = number }
variable "bastion_security_group_id" { type = string }
variable "bastion_role_arn"          { type = string }
variable "admin_principal_arns"      {
  type    = list(string)
  default = []
}
