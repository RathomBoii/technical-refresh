output "cluster_endpoint"          { value = module.eks.cluster_endpoint }
output "cluster_ca_data"           { value = module.eks.cluster_certificate_authority_data }
output "cluster_name"              { value = module.eks.cluster_name }

# OICD provider details for IRSA, which IAM module needs to create the trust policy
output "oidc_provider_arn"         { value = module.eks.oidc_provider_arn }

output "oidc_provider"             { value = module.eks.oidc_provider }
output "node_security_group_id"    { value = module.eks.node_security_group_id }
