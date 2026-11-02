env                   = "dev"
domain_name           = "example.com"        # 自分のドメインに変更（5-1-1）
cognito_domain_prefix = "mini-blog-dev-xxxx" # 4-1 で決めた文字
alarm_email           = "you@example.com"    # 自分のメールアドレスにする
log_retention_days    = 14
api_desired_count     = 1
app_desired_count     = 1
# deletion_protection は書かない（初期値の false。dev は削除保護なし）
github_repository = "OWNER@12345678/mini-blog" # 12345678 はオーナーの ID（5-2-2）
