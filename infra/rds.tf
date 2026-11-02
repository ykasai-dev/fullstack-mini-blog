# DB のパスワードを生成する
# 値は state に保存されるので、state は暗号化した S3 に置く（4-1）
resource "random_password" "db" {
  length  = 32
  special = false # URL（DATABASE_URL）に入れても壊れないよう、英数字だけにする
}

# RDS を配置するサブネット（プライベートサブネット 2つ）
# RDS は、2つ以上の AZ のサブネットを指定する必要がある
resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
  identifier     = local.name # コンソールに表示される名前
  engine         = "postgres"
  engine_version = "17"           # 手元（Docker の postgres:17）に合わせる
  instance_class = "db.t4g.micro" # 最小のインスタンスサイズ

  allocated_storage     = 20  # ストレージ 20GB
  max_allocated_storage = 100 # 空きが少なくなったら、100GB まで自動で増やす
  storage_type          = "gp3"
  storage_encrypted     = true # ストレージを暗号化する

  db_name  = "blog" # 作成するデータベース名
  username = "postgres"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id] # API のタスクからのアクセスのみ許可（5-1-4）
  publicly_accessible    = false                      # 外部からアクセスできないようにする

  backup_retention_period = 7 # 自動バックアップを 7日間保存する
  copy_tags_to_snapshot   = true

  # prod のみ：別の AZ にスタンバイを置く／削除保護を有効にする
  multi_az            = local.is_prod
  deletion_protection = var.deletion_protection

  # 削除するときのスナップショット：prod は取る、dev は取らない
  skip_final_snapshot       = !local.is_prod
  final_snapshot_identifier = local.is_prod ? "${local.name}-final" : null

  # 設定の変更：dev はすぐ反映、prod は次のメンテナンスの時間に反映する（再起動を伴うことがあるため）
  apply_immediately = !local.is_prod
}

# ── Secrets Manager：DATABASE_URL を保存する ──

resource "aws_secretsmanager_secret" "database_url" {
  name = "mini-blog/${var.env}/database-url"

  # 削除したあと、復元できる期間（日）
  # dev は 0（すぐに削除し、同じ名前で作り直せるようにする）
  recovery_window_in_days = local.is_prod ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id = aws_secretsmanager_secret.database_url.id

  # キー DATABASE_URL に接続文字列を入れる（タスク定義で :DATABASE_URL:: と指定する。5-1-10）
  secret_string = jsonencode({
    DATABASE_URL = format(
      "postgresql://%s:%s@%s:%d/%s?schema=public&sslmode=require&uselibpqcompat=true",
      aws_db_instance.main.username,
      random_password.db.result,
      aws_db_instance.main.address, # RDS のエンドポイント（ホスト名）
      aws_db_instance.main.port,    # 5432
      aws_db_instance.main.db_name,
    )
  })
}
