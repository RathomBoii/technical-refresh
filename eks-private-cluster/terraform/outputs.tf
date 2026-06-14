output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL for app image"
  value       = module.ecr.repository_url
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "app_irsa_role_arn" {
  description = "IAM role ARN for app pod — use as serviceAccount.roleArn in values-dev/prod.yaml"
  value       = module.iam.app_role_arn
}

output "app_api_key_secret_name" {
  description = "Secrets Manager secret name for app api-key — use as objectName in SecretProviderClass"
  value       = module.secrets.app_api_key_secret_name
}

output "lbc_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller — use in helm install"
  value       = module.iam.lbc_role_arn
}

output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator — paste into secret-store values as serviceAccount.irsaRoleArn"
  value       = module.iam.eso_role_arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions — set as AWS_ROLE_TO_ASSUME in GitHub repository variables"
  value       = module.iam.github_actions_role_arn
}
