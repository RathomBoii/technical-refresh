output "db_endpoint" {
  description = "RDS instance endpoint (host:port) — use this in pgadmin connection settings"
  value       = aws_db_instance.this.endpoint
}

output "db_host" {
  description = "RDS hostname only (without port)"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name"
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
}

output "db_password_secret_arn" {
  description = "ARN of the Secrets Manager secret storing the RDS password — mount in pgadmin pod via External Secrets or retrieve with aws secretsmanager get-secret-value"
  value       = aws_secretsmanager_secret.db_password.arn
}
