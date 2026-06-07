output "helloworld_role_arn" {
  description = "IAM role ARN for helloworld pod — paste into values-dev/prod.yaml as serviceAccount.roleArn"
  value       = aws_iam_role.helloworld.arn
}

output "helloworld_api_key_secret_name" {
  description = "Secrets Manager secret name — use as objectName in SecretProviderClass"
  value       = var.helloworld_api_key_secret_name
}

output "lbc_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller — use in helm install --set serviceAccount.annotations"
  value       = aws_iam_role.lbc.arn
}
output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator — paste into secret-store values as serviceAccount.irsaRoleArn"
  value       = aws_iam_role.eso.arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions CI/CD — set as AWS_ROLE_TO_ASSUME in GitHub repository variables"
  value       = aws_iam_role.github_actions.arn
}