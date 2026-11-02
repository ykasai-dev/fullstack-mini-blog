output "images_bucket" {
  description = "画像のバケット名（API の環境変数 S3_BUCKET）"
  value       = aws_s3_bucket.images.bucket
}

output "cognito_user_pool_id" {
  description = "API の環境変数 COGNITO_USER_POOL_ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "API の COGNITO_CLIENT_ID、画面の NEXT_PUBLIC_COGNITO_CLIENT_ID"
  value       = aws_cognito_user_pool_client.web.id
}

output "cognito_domain" {
  description = "画面の NEXT_PUBLIC_COGNITO_DOMAIN"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
}

output "app_url" {
  description = "画面の URL（NEXT_PUBLIC_APP_URL）"
  value       = "https://${local.app_domain}"
}

output "api_url" {
  description = "API の URL（NEXT_PUBLIC_API_URL）"
  value       = "https://${local.api_domain}"
}

output "ecr_repository_urls" {
  description = "ECR のリポジトリの URL（docker push の送り先）"
  value       = { for k, r in aws_ecr_repository.main : k => r.repository_url }
}

output "github_actions_role_arn" {
  description = "GitHub Actions の role-to-assume に指定する（5-2-3）"
  value       = aws_iam_role.github_actions.arn
}
