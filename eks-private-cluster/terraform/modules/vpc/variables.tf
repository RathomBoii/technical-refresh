variable "env"             { type = string }
variable "cluster_name"    { type = string }
variable "vpc_cidr"        { type = string }
variable "private_subnets" { type = list(string) }
variable "public_subnets"  { type = list(string) }
variable "region"          { type = string }
variable "is_single_nat_gateway" {
  description = "Whether to use a single NAT gateway"
  type        = bool
}