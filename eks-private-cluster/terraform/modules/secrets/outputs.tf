output "app_api_key_secret_arn" {
  description = "Secrets Manager ARN for app api-key — referenced by the IRSA policy in the iam module"
  value       = aws_secretsmanager_secret.app_json.arn
}

output "app_api_key_secret_name" {
  description = "Secrets Manager secret name — use as objectName in SecretProviderClass"
  value       = aws_secretsmanager_secret.app_json.name
}

output "app_json_secret_name" {
  description = "Secrets Manager secret name for ExternalSecret — must match externalSecret.key in secret-store values"
  value       = aws_secretsmanager_secret.app_json.name
}
