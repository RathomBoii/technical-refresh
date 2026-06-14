# ── JSON secret for ExternalSecret (external-secrets operator) ───────────────
# The ExternalSecret chart uses dataFrom.extract.key: "<env>/app"
# which expects the AWS secret to be a JSON object.
# conversionStrategy: Default unpacks each JSON key into a separate k8s Secret key.
# Result: k8s Secret "app-secrets" will contain key "API_KEY".
resource "aws_secretsmanager_secret" "app_json" {
  name                    = "${var.env}/app"
  description             = "JSON bundle of all app secrets (${var.env}) — fetched by ExternalSecret"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.env}-app-json"
    Env  = var.env
    App  = "app"
  }
}

resource "aws_secretsmanager_secret_version" "app_json" {
  secret_id = aws_secretsmanager_secret.app_json.id
  # JSON object — each top-level key becomes a separate key in the k8s Secret
  # The actual secret will look like this in AWS Secrets Manager:
  # Name:  dev/app
  # Value: {"API_KEY": "your-actual-api-key-value"}   ← JSON object
  secret_string = jsonencode({
    API_KEY = var.app_api_key_value
  })
}
