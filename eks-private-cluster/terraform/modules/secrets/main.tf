# ── Secrets Manager secrets for helloworld ────────────────────────────────────
# These are the actual secrets the helloworld pod reads at runtime via the
# CSI Secrets Store driver. The SecretProviderClass in the Helm chart references
# the secret name below as objectName.

resource "aws_secretsmanager_secret" "helloworld_api_key" {
  name                    = "/${var.env}/helloworld/api-key"
  description             = "API key for helloworld application (${var.env})"
  recovery_window_in_days = 0 # Force immediate deletion — avoids "scheduled for deletion" error on re-apply

  tags = {
    Name = "${var.env}-helloworld-api-key"
    Env  = var.env
    App  = "helloworld"
  }
}

resource "aws_secretsmanager_secret_version" "helloworld_api_key" {
  secret_id     = aws_secretsmanager_secret.helloworld_api_key.id
  secret_string = var.helloworld_api_key_value
}

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
  secret_string = jsonencode({
    API_KEY = var.helloworld_api_key_value
  })
}
