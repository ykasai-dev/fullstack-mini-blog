resource "aws_cognito_user_pool" "main" {
  name = local.name

  # ログインの識別子をメールアドレスにする（作成後に変更できない）
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # 自己登録をオフにする：ユーザーを作成できるのは管理者だけ
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  # パスワードを忘れたときは、確認済みのメールアドレスでリセットする
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # 本番環境のみ：誤って削除できないようにする（削除するとユーザーがすべて消える）
  deletion_protection = var.deletion_protection ? "ACTIVE" : "INACTIVE"
}

# ログイン画面のドメイン：https://（prefix）.auth.us-east-1.amazoncognito.com
resource "aws_cognito_user_pool_domain" "main" {
  domain                = var.cognito_domain_prefix
  user_pool_id          = aws_cognito_user_pool.main.id
  managed_login_version = 2 # ログイン画面を Managed Login（新しいログイン画面）にする
}

resource "aws_cognito_user_pool_client" "web" {
  name         = local.name
  user_pool_id = aws_cognito_user_pool.main.id

  # SPA：ブラウザに渡すコードは誰でも読めるので、クライアントシークレットを持たない
  generate_secret = false

  # OAuth 2.0 の設定
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]            # 認可コード付与のみ
  allowed_oauth_scopes                 = ["openid", "email"] # 必要な情報だけを受け取る
  supported_identity_providers         = ["COGNITO"]         # ユーザープールのユーザーでログインする

  # ログイン後に戻る URL・ログアウト後に戻る URL（ここにない URL には戻さない）
  # dev だけ、手元の PC（npm run dev・Docker）の URL も許可する
  callback_urls = concat(
    ["https://${local.app_domain}/callback"],
    local.is_prod ? [] : ["http://localhost:3000/callback"],
  )
  logout_urls = concat(
    ["https://${local.app_domain}/"],
    local.is_prod ? [] : ["http://localhost:3000/"],
  )

  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  # 存在しないユーザーでログインしたときも、「ユーザーがいない」とは返さない
  prevent_user_existence_errors = "ENABLED"
}

# Managed Login のログイン画面の見た目（Cognito の初期のデザインを使う）
# Managed Login では、アプリクライアントごとにこの設定がないとログイン画面が表示されない
resource "aws_cognito_managed_login_branding" "web" {
  user_pool_id                = aws_cognito_user_pool.main.id
  client_id                   = aws_cognito_user_pool_client.web.id
  use_cognito_provided_values = true
}
