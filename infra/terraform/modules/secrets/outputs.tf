output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt.arn
}

output "play_service_account_secret_arn" {
  value = aws_secretsmanager_secret.play_service_account.arn
}

output "firebase_secret_arn" {
  value = aws_secretsmanager_secret.firebase.arn
}

output "all_secret_arns" {
  value = [
    aws_secretsmanager_secret.jwt.arn,
    aws_secretsmanager_secret.play_service_account.arn,
    aws_secretsmanager_secret.firebase.arn,
  ]
}
