# ── JSON secret for ExternalSecret (external-secrets operator) ───────────────
# The ExternalSecret chart uses dataFrom.extract.key: "<env>/helloworld"
# which expects the AWS secret to be a JSON object.
# conversionStrategy: Default unpacks each JSON key into a separate k8s Secret key.
# Result: k8s Secret "helloworld-secrets" will contain key "API_KEY".
resource "aws_secretsmanager_secret" "helloworld_json" {
  name                    = "${var.env}/helloworld"
  description             = "JSON bundle of all helloworld secrets (${var.env}) — fetched by ExternalSecret"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.env}-helloworld-json"
    Env  = var.env
    App  = "helloworld"
  }
}

resource "aws_secretsmanager_secret_version" "helloworld_json" {
  secret_id = aws_secretsmanager_secret.helloworld_json.id
  # JSON object — each top-level key becomes a separate key in the k8s Secret
  # The actual secret will look like this in AWS Secrets Manager:
  # Name:  dev/helloworld
  # Value: {"API_KEY": "your-actual-api-key-value"}   ← JSON object
  secret_string = jsonencode({
    API_KEY = var.helloworld_api_key_value
  })
}
