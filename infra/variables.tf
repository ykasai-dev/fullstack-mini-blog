variable "env" {
  description = "環境の名前"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env は dev か prod にしてください。"
  }
}

variable "region" {
  description = "AWS のリージョン"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "独自ドメイン（例：example.com）。画面の URL の組み立てに使う"
  type        = string
}

variable "cognito_domain_prefix" {
  description = "Cognito のログイン画面のドメインの先頭部分（リージョン内で一意にする）"
  type        = string
}

variable "alarm_email" {
  description = "アラームの通知を受け取るメールアドレス（5-1-11）"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs の保持期間（日）（5-1-10）"
  type        = number
}

variable "api_desired_count" {
  description = "API のタスクの数"
  type        = number
}

variable "app_desired_count" {
  description = "画面（Next.js）のタスクの数"
  type        = number
}

variable "deletion_protection" {
  description = "RDS・ALB・Cognito の削除保護。false のときは S3・ECR を中身ごと削除できる（prod は true。削除するときだけ false にする。5-4-1）"
  type        = bool
  default     = false
}

# 名前の組み立て（各ファイルから local.name のように使う）
locals {
  name = "mini-blog-${var.env}" # 例：mini-blog-dev

  # 画面と API のホスト名
  # prod：app.example.com / api.example.com
  # dev ：app.dev.example.com / api.dev.example.com
  host_suffix = var.env == "prod" ? var.domain_name : "${var.env}.${var.domain_name}"
  app_domain  = "app.${local.host_suffix}"
  api_domain  = "api.${local.host_suffix}"

  is_prod = var.env == "prod"
}

# 今ログインしているアカウントの情報（アカウント ID をバケット名に使う）
data "aws_caller_identity" "current" {}

variable "github_repository" {
  description = "GitHub Actions を許可するリポジトリ（OWNER@OWNER_ID/REPO の形。5-2-2）"
  type        = string
}
