terraform {
  required_version = ">= 1.11" # use_lockfile（S3 だけでロックする機能）が正式な機能になったバージョン

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # 6.x の範囲で最新を使う（7.0 には上げない）
    }
    random = {
      source  = "hashicorp/random" # DB のパスワードの生成に使う（5-1-8）
      version = "~> 3.6"
    }
  }

  # state を S3 に置く。中身は環境ごとの .tfbackend ファイルで指定する
  # （backend のブロックには変数を使えないため）
  backend "s3" {}
}

provider "aws" {
  region = var.region
  # 認証情報は書かない。環境変数 AWS_PROFILE（IAM Identity Center）を使う

  # すべてのリソースに付けるタグ（費用の集計や、どの環境のものかの確認に使う）
  default_tags {
    tags = {
      Project   = "mini-blog"
      Env       = var.env
      ManagedBy = "terraform"
    }
  }
}
