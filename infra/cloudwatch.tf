# ── 通知先：SNS のトピックと、メールの購読 ──
resource "aws_sns_topic" "alarm" {
  name = "${local.name}-alarm"
}

# apply のあとに確認のメールが届く。メールのリンクを押すまで、通知は届かない
resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

locals {
  alarm_actions = [aws_sns_topic.alarm.arn]
}

# ── ALB：5xx エラー ──
# Target_5XX：アプリ（タスク）が返した 5xx ／ ELB_5XX：ALB 自身が返した 5xx（healthy なタスクがない 503 など）
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  for_each = toset(["HTTPCode_Target_5XX_Count", "HTTPCode_ELB_5XX_Count"])

  alarm_name          = "${local.name}-alb-${each.key}"
  namespace           = "AWS/ApplicationELB"
  metric_name         = each.key
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix }
  statistic           = "Sum"
  period              = 300 # 5分ごとに集計する
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 10             # 5分間に 10回以上
  treat_missing_data  = "notBreaching" # エラーが1件もない時間はデータがないので、正常として扱う

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions # 正常に戻ったときも通知する
}

# ── ECS：CPU 使用率（API と画面）──
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  for_each = {
    api = aws_ecs_service.api.name
    app = aws_ecs_service.app.name
  }

  alarm_name  = "${local.name}-ecs-${each.key}-cpu"
  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = each.value
  }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3 # 15分続いたら（一時的な上昇では通知しない）
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80 # 80% を超えたら

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

# ── RDS：CPU 使用率 ──
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name}-rds-cpu"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

# ── RDS：ストレージの空き容量 ──
resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name}-rds-free-storage"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace" # 単位はバイト
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = 2 * 1024 * 1024 * 1024 # 2GB を下回ったら

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}
