# ── セキュリティグループ（4つ）──
# aws_security_group で作成すると、初期値の「アウトバウンドをすべて許可」のルールは削除される
# そのため、必要なアウトバウンドのルールは下で明示的に作成する

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "ALB for mini-blog" # 説明は英語のみ使える
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "api" {
  name        = "${local.name}-api"
  description = "ECS tasks for mini-blog API"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "ECS tasks for mini-blog web app"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "RDS for mini-blog"
  vpc_id      = aws_vpc.main.id
}

# ── インバウンド（外から入ってくる通信）──

# ALB：443 と 80 をインターネットから許可する（80 は 443 にリダイレクトする。5-1-7）
resource "aws_vpc_security_group_ingress_rule" "alb" {
  for_each = toset(["80", "443"])

  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
  cidr_ipv4         = "0.0.0.0/0"
}

# API のタスク：3001 を ALB からのアクセスのみ許可する
# （ALB の IP アドレスは変わることがあるので、IP ではなくセキュリティグループで指定する）
resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id            = aws_security_group.api.id
  ip_protocol                  = "tcp"
  from_port                    = 3001
  to_port                      = 3001
  referenced_security_group_id = aws_security_group.alb.id
}

# 画面のタスク：3000 を ALB からのアクセスのみ許可する
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.alb.id
}

# RDS：5432 を API のタスクからのアクセスのみ許可する（画面のタスクからはアクセスできない）
resource "aws_vpc_security_group_ingress_rule" "db_from_api" {
  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.api.id
}

# ── アウトバウンド（中から外への通信）──

# ALB：VPC の中（タスク）への通信だけを許可する
resource "aws_vpc_security_group_egress_rule" "alb_to_vpc" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1" # すべてのプロトコル
  cidr_ipv4         = aws_vpc.main.cidr_block
}

# タスク：すべて許可する（NAT ゲートウェイ経由で ECR・Cognito・Secrets Manager などにアクセスするため）
resource "aws_vpc_security_group_egress_rule" "tasks_to_all" {
  for_each = {
    api = aws_security_group.api.id
    app = aws_security_group.app.id
  }

  security_group_id = each.value
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# RDS：アウトバウンドのルールは作らない
# （セキュリティグループは、許可した通信への応答は自動で通すため、API への応答は返せる）
