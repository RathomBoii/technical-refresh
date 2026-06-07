output "helloworld_api_key_secret_arn" {
  description = "Secrets Manager ARN for helloworld api-key — referenced by the IRSA policy in the iam module"
  value       = aws_secretsmanager_secret.helloworld_api_key.arn
}

output "helloworld_api_key_secret_name" {
  description = "Secrets Manager secret name — use as objectName in SecretProviderClass"
  value       = aws_secretsmanager_secret.helloworld_api_key.name
}

output "helloworld_json_secret_name" {
  description = "Secrets Manager secret name for ExternalSecret — must match externalSecret.key in secret-store values"
  value       = aws_secretsmanager_secret.helloworld_json.name
}

output "helloworld_json_secret_name" {
  description = "Secrets Manager secret name for ExternalSecret — must match externalSecret.key in secret-store values"
  value       = aws_secretsmanager_secret.helloworld_json.name
}
