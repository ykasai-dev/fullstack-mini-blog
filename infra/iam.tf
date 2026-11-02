# ── ECS のタスクが使うロールの信頼ポリシー（2つのロールで共通）──
# 「ECS のタスク（ecs-tasks.amazonaws.com）が、このロールを使ってよい」
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    # 自分のアカウントの ECS からのみ使えるようにする
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# ── タスク実行ロール ──
resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# AWS 管理ポリシー：ECR からのイメージの取得と、CloudWatch Logs へのログの送信
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager から DATABASE_URL を取得する許可（このシークレットだけ）
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "read-database-url"
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      # ECR へのログイン（リソースは指定できないので * にする）
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.database_url.arn
    }]
  })
}

# ── タスクロール（API 用）──
resource "aws_iam_role" "api_task" {
  name               = "${local.name}-api-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# 画像のバケット（4-1）の中に、保存（PutObject）と取得（GetObject）だけを許可する
# 署名付き URL は、使われるときに、署名したこのロールの権限で確かめられる
resource "aws_iam_role_policy" "api_task_s3" {
  name = "images-access"
  role = aws_iam_role.api_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = "${aws_s3_bucket.images.arn}/*"
    }]
  })
}

# ── GitHub Actions 用のロール（OIDC）──

# 上で AWS CLI で作成した ID プロバイダを参照する
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# 信頼ポリシー：指定したリポジトリの、この環境（GitHub の環境 dev・prod）を指定したジョブだけが使える
# dev のロールは dev の環境のジョブだけ、prod のロールは prod の環境のジョブだけが使える
# 信頼ポリシー：指定したリポジトリの、main ブランチのジョブだけが使える
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike" # * を使うので StringLike
      variable = "token.actions.githubusercontent.com:sub"
      # 例：repo:OWNER@12345678/mini-blog@*:ref:refs/heads/main（GitHub Free の Private リポジトリでは environments が使えないため、main ブランチを信頼する）
      # 例：repo:OWNER@12345678/mini-blog@*:ref:refs/heads/main（@* はリポジトリの ID）
      values = ["repo:${var.github_repository}@*:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${local.name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "deploy"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR へのログイン（リソースは指定できないので * にする）
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # この環境の2つのリポジトリにだけ、イメージを push できる
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:DescribeImages", # 同じタグのイメージがすでにあるかの確認に使う（5-2-4）
        ]
        Resource = [for r in aws_ecr_repository.main : r.arn]
      },
      {
        # タスク定義の取得と登録（リソースは指定できないので * にする）
        Effect   = "Allow"
        Action   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
        Resource = "*"
      },
      {
        # この環境の2つのサービスだけを更新できる
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
        Resource = [aws_ecs_service.api.arn, aws_ecs_service.app.arn] # サービスの ARN
      },
      {
        # マイグレーション用に、API のタスク定義で1回だけのタスクを起動できる
        Effect   = "Allow"
        Action   = "ecs:RunTask"
        Resource = "arn:aws:ecs:${var.region}:${local.account_id}:task-definition/${local.name}-api:*"
      },
      {
        Effect   = "Allow"
        Action   = "ecs:DescribeTasks"
        Resource = "*"
      },
      {
        # 新しいタスク定義に、2つのロールを設定するための許可（ECS に渡すときだけ）
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = [aws_iam_role.ecs_execution.arn, aws_iam_role.api_task.arn]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      },
    ]
  })
}
