# mini-blog-dev-api・mini-blog-dev-app の2つを作成する
resource "aws_ecr_repository" "main" {
  for_each = toset(["api", "app"])

  name = "${local.name}-${each.key}"

  # 同じタグでの上書きを禁止する（タグはコミットの SHA にする）
  # どのコミットのイメージが動いているかが、タグから確実にわかる
  image_tag_mutability = "IMMUTABLE"

  # push したときに、イメージの脆弱性をスキャンする
  image_scanning_configuration {
    scan_on_push = true
  }

  # 削除保護がないとき（dev、片付けるときの prod）は、イメージが残っていても
  # terraform destroy でリポジトリごと削除できるようにする（5-1-2・5-4-1）
  force_delete = !var.deletion_protection
}

# 古いイメージを自動で削除する（保存している容量に料金がかかるため）
resource "aws_ecr_lifecycle_policy" "main" {
  for_each = aws_ecr_repository.main

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30 # 新しい 30 個だけ残す（前のバージョンに戻せる範囲）
      }
      action = { type = "expire" }
    }]
  })
}
