# Application secrets. The DB master credential is managed by RDS itself
# (manage_master_user_password) and rotated by AWS; see the rds module.

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.name}/jwt-signing-key"
  description             = "HMAC signing key for Puzzle Hub access tokens"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt.result

  lifecycle {
    # Rotation is done out-of-band (dual-key rollover); never clobber it on apply.
    ignore_changes = [secret_string]
  }
}

# Google Play Developer API service-account JSON (purchase verification).
# Terraform creates the container only; the value is uploaded by an operator:
#   aws secretsmanager put-secret-value --secret-id <name>/play-service-account --secret-string file://sa.json
resource "aws_secretsmanager_secret" "play_service_account" {
  name                    = "${var.name}/play-service-account"
  description             = "Google Play Developer API service account JSON"
  recovery_window_in_days = var.recovery_window_in_days
}

# Firebase project id + optional admin credentials for ID-token verification / FCM.
resource "aws_secretsmanager_secret" "firebase" {
  name                    = "${var.name}/firebase"
  description             = "Firebase service account JSON for FCM"
  recovery_window_in_days = var.recovery_window_in_days
}
