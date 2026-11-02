# 使える AZ の一覧から、先頭の2つ（us-east-1a・us-east-1b など）を使う
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # NAT ゲートウェイの数：prod は AZ ごとに1つ（片方の AZ が止まっても外に出られる）
  # dev は費用を抑えるため1つだけ
  nat_count = local.is_prod ? 2 : 1
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # VPC 全体の IP アドレスの範囲
  enable_dns_support   = true
  enable_dns_hostnames = true # VPC エンドポイントなどで DNS 名を使うために有効にする

  tags = { Name = local.name }
}

# パブリックサブネット（ALB・NAT ゲートウェイを置く）
# cidrsubnet で /16 を /24 に区切る：10.0.0.0/24、10.0.1.0/24
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = local.azs[count.index]

  tags = { Name = "${local.name}-public-${local.azs[count.index]}" }
}

# プライベートサブネット（ECS のタスク・RDS を置く）：10.0.10.0/24、10.0.11.0/24
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = { Name = "${local.name}-private-${local.azs[count.index]}" }
}

# インターネットゲートウェイ（VPC とインターネットの間の出入口）
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = local.name }
}

# パブリックサブネットのルートテーブル：VPC の外への通信はインターネットゲートウェイへ
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name}-public" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT ゲートウェイに付ける固定のパブリック IP（Elastic IP）
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-${count.index}" }
}

# NAT ゲートウェイ：プライベートサブネットから外への通信だけを中継する
# （外からプライベートサブネットへの通信は通さない）
resource "aws_nat_gateway" "main" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # NAT ゲートウェイはパブリックサブネットに置く

  tags       = { Name = "${local.name}-${local.azs[count.index]}" }
  depends_on = [aws_internet_gateway.main]
}

# プライベートサブネットのルートテーブル（AZ ごとに1つ）
# VPC の外への通信は NAT ゲートウェイへ。dev は2つとも同じ NAT ゲートウェイを使う
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[min(count.index, local.nat_count - 1)].id
  }

  tags = { Name = "${local.name}-private-${local.azs[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# S3 のゲートウェイエンドポイント（無料）
# ECR のイメージの実体は S3 に置かれているため、イメージの取得の通信が NAT ゲートウェイを通らなくなる
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = { Name = "${local.name}-s3" }
}
