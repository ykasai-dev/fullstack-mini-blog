resource "aws_s3_bucket" "images" {
  # バケット名は世界で一意にする必要があるので、アカウント ID を付ける
  bucket = "${local.name}-images-${data.aws_caller_identity.current.account_id}"

  # dev は、画像が残っていても terraform destroy で削除できるようにする
  force_destroy = !var.deletion_protection
}

# パブリックアクセスをすべてブロックする（非公開のバケットにする）
resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACL を無効にする（アクセスの許可は IAM のポリシーだけで管理する）
resource "aws_s3_bucket_ownership_controls" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# 保存するファイルを暗号化する（SSE-S3）
resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CORS：画面の URL から、署名付き URL での PUT（アップロード）と GET（表示）を許可する
resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    # dev だけ、手元の PC（http://localhost:3000）からのアクセスも許可する
    allowed_origins = concat(
      ["https://${local.app_domain}"],
      local.is_prod ? [] : ["http://localhost:3000"],
    )
    allowed_methods = ["PUT", "GET"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000 # ブラウザが CORS の確認結果を覚えておく秒数
  }
}
