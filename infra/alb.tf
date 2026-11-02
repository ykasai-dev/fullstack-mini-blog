# ── Route 53 と ACM（証明書）──

# 既存のホストゾーン（5-1-1 で確認したもの）を参照する
data "aws_route53_zone" "main" {
  name = var.domain_name
}

# 証明書を発行する：app と api の2つのホスト名を1枚の証明書に入れる
resource "aws_acm_certificate" "main" {
  domain_name               = local.app_domain
  subject_alternative_names = [local.api_domain]
  validation_method         = "DNS" # Route 53 にレコードを作成して、ドメインの持ち主であることを証明する

  lifecycle {
    create_before_destroy = true # 作り直すときは、新しい証明書を先に作成する
  }
}

# ドメインの持ち主であることを証明するための DNS レコード（ホスト名ごとに1つ）
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# 証明書の発行が終わるまで待つ（終わる前に HTTPS のリスナーを作ると失敗するため）
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ── ALB ──

# ── ALB ──
resource "aws_lb" "main" {
  name               = local.name
  load_balancer_type = "application"
  internal           = false                   # インターネットからアクセスできる ALB
  subnets            = aws_subnet.public[*].id # パブリックサブネット（2つの AZ）に置く
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true                    # 不正な HTTP ヘッダーを持つリクエストを捨てる
  enable_deletion_protection = var.deletion_protection # prod のみ：誤って削除できないようにする
}

# ターゲットグループ：API のタスク（3001）
resource "aws_lb_target_group" "api" {
  name        = "${local.name}-api"
  target_type = "ip" # Fargate のタスクは IP アドレスで登録される
  protocol    = "HTTP"
  port        = 3001
  vpc_id      = aws_vpc.main.id

  deregistration_delay = 30 # タスクを入れ替えるとき、古いタスクへの振り分けを止めてから待つ秒数（初期値 300）

  health_check {
    path    = "/" # NestJS の GET / が 200（Hello World!）を返す
    matcher = "200"
  }
}

# ターゲットグループ：画面のタスク（3000）
resource "aws_lb_target_group" "app" {
  name                 = "${local.name}-app"
  target_type          = "ip"
  protocol             = "HTTP"
  port                 = 3000
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path    = "/" # 記事の一覧の画面
    matcher = "200"
  }
}

# ── リスナー ──

# HTTP（80）：同じ URL の HTTPS にリダイレクトする
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301" # 恒久的なリダイレクト
    }
  }
}

# HTTPS（443）：ホスト名で振り分ける。どれにも合わないときは 404 を返す
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # TLS 1.2 と 1.3 だけを使う
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# ルール：Host が app.… なら画面に、api.… なら API に振り分ける
resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10 # 数字が小さいルールから順に判定する

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    host_header {
      values = [local.app_domain]
    }
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    host_header {
      values = [local.api_domain]
    }
  }
}

# ── DNS：app.… と api.… を ALB に向ける ──
# エイリアスレコードを使うと、ALB の IP アドレスが変わっても自動で追従する
resource "aws_route53_record" "alb" {
  for_each = toset([local.app_domain, local.api_domain])

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.key
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
