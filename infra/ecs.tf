# ── ECR にある最新のイメージ ──
# 初回は 5-1-6 で push したイメージ。2回目からのデプロイは GitHub Actions が行う（5-2）
data "aws_ecr_image" "api" {
  repository_name = aws_ecr_repository.main["api"].name
  most_recent     = true
}

data "aws_ecr_image" "app" {
  repository_name = aws_ecr_repository.main["app"].name
  most_recent     = true
}

# ── ロググループ（タスクの画面出力の送り先）──
# 保持期間の初期値は「失効しない」で、保存の料金がかかり続けるため、日数を指定する
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name}-api"
  retention_in_days = var.log_retention_days # dev は 14日、prod は 90日（指定できる日数は 1・3・5・7・14・30・60・90 など決まっている）
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}-app"
  retention_in_days = var.log_retention_days
}

# ── クラスター ──
resource "aws_ecs_cluster" "main" {
  name = local.name # mini-blog-dev

  # Container Insights：タスクごとの CPU・メモリなどの詳しいメトリクスを集める（有料なので prod だけ）
  setting {
    name  = "containerInsights"
    value = local.is_prod ? "enabled" : "disabled"
  }
}

# ── タスク定義：API ──
resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"                       # Fargate はこれだけ
  cpu                      = "256"                          # .25 vCPU
  memory                   = "512"                          # .5 GB
  execution_role_arn       = aws_iam_role.ecs_execution.arn # タスク実行ロール（5-1-9）
  task_role_arn            = aws_iam_role.api_task.arn      # タスクロール（5-1-9）

  # タスクロールなし（画面は AWS のサービスを使わない）
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64" # イメージ（linux/arm64）に合わせる
  }

  container_definitions = jsonencode([{
    name         = "api" # GitHub Actions でイメージを差し替えるときに、この名前で指定する
    image        = "${aws_ecr_repository.main["api"].repository_url}@${data.aws_ecr_image.api.image_digest}"
    essential    = true
    portMappings = [{ containerPort = 3001, protocol = "tcp" }]

    # 手元の backend/.env と同じ値を、AWS の値で渡す（DATABASE_URL だけは下の secrets）
    environment = [
      { name = "PORT", value = "3001" },
      { name = "AWS_REGION", value = var.region },
      { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
      { name = "COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.web.id },
      { name = "S3_BUCKET", value = aws_s3_bucket.images.bucket },
      { name = "CORS_ORIGIN", value = "https://${local.app_domain}" }, # 画面のドメインからの呼び出しだけを許可する
      { name = "NO_COLOR", value = "1" },                              # NestJS のログに色の制御文字を付けない（CloudWatch Logs で読みやすくする）
    ]

    # Secrets Manager のシークレットの中の、DATABASE_URL というキーの値だけを渡す
    secrets = [
      { name = "DATABASE_URL", valueFrom = "${aws_secretsmanager_secret.database_url.arn}:DATABASE_URL::" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# ── タスク定義：画面（Next.js）──
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  # タスクロールなし（画面は AWS のサービスを使わない）

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name         = "app"
    image        = "${aws_ecr_repository.main["app"].repository_url}@${data.aws_ecr_image.app.image_digest}"
    essential    = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    environment  = [{ name = "PORT", value = "3000" }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# ── サービス：API ──
resource "aws_ecs_service" "api" {
  name            = "${local.name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id # プライベートサブネット（2つの AZ）
    security_groups  = [aws_security_group.api.id]
    assign_public_ip = false # パブリック IP を付けない（外への通信は NAT ゲートウェイ）
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 3001
  }

  # 起動直後のヘルスチェックの失敗を無視する秒数（アプリの起動を待つ）
  health_check_grace_period_seconds = 60

  # 新しいタスクが起動に失敗し続けたら、デプロイを止めて前のタスク定義に戻す
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    # デプロイ（タスク定義の切り替え）は GitHub Actions が行うので、Terraform では元に戻さない（5-2）
    ignore_changes = [task_definition]
  }

  depends_on = [
    aws_lb_listener_rule.api,                       # ALB のルールを先に作成する
    aws_secretsmanager_secret_version.database_url, # DB の接続文字列（金庫の中身）を先に入れる
  ]
}

# ── サービス：画面 ──
resource "aws_ecs_service" "app" {
  name            = "${local.name}-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 3000
  }

  health_check_grace_period_seconds = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener_rule.app]
}
