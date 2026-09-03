# =========================================================================
# VPC PER APPLICATION — the core "blast radius" boundary.
# App A and App B each get their own VPC. There is NO VPC peering and NO
# default route between them: a compromise in one cannot reach the other
# at the network layer, only via the explicitly-controlled Transit Hub
# (represented here by aws_ec2_transit_gateway + explicit route tables).
# =========================================================================

resource "aws_vpc" "app_a" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vpc-app-a", app = "app-a" }
}

resource "aws_vpc" "app_b" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vpc-app-b", app = "app-b" }
}

resource "aws_subnet" "app_a_private" {
  vpc_id     = aws_vpc.app_a.id
  cidr_block = "10.10.1.0/24"
  tags       = { Name = "app-a-private-subnet" }
}

resource "aws_subnet" "app_b_private" {
  vpc_id     = aws_vpc.app_b.id
  cidr_block = "10.20.1.0/24"
  tags       = { Name = "app-b-private-subnet" }
}

# =========================================================================
# SECURITY GROUPS — least-privilege, tier-scoped, deny-by-default (AWS SGs
# are implicitly default-deny already; we only add explicit allows).
# =========================================================================

resource "aws_security_group" "app_a_frontend_sg" {
  name = "app-a-frontend-sg"
  description = "Allows inbound HTTPS from the ZTNA gateway ONLY"
  vpc_id      = aws_vpc.app_a.id

  ingress {
    description = "HTTPS from ZTNA gateway subnet only, never 0.0.0.0/0"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.99.0.0/24"] # dedicated ZTNA gateway subnet
  }
}

resource "aws_security_group" "app_a_backend_sg" {
  name = "app-a-backend-sg"
  description = "Allows inbound traffic ONLY from app-a frontend SG"
  vpc_id      = aws_vpc.app_a.id

  ingress {
    description     = "App tier traffic from app-a frontend only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.app_a_frontend_sg.id]
  }
}

resource "aws_security_group" "app_b_frontend_sg" {
  name = "app-b-frontend-sg"
  description = "Allows inbound HTTPS from the ZTNA gateway ONLY"
  vpc_id      = aws_vpc.app_b.id

  ingress {
    description = "HTTPS from ZTNA gateway subnet only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.99.0.0/24"]
  }
}

resource "aws_security_group" "app_b_backend_sg" {
  name = "app-b-backend-sg"
  description = "Allows inbound traffic ONLY from app-b frontend SG"
  vpc_id      = aws_vpc.app_b.id

  ingress {
    description     = "App tier traffic from app-b frontend only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.app_b_frontend_sg.id]
  }
}
# NOTE: no rule anywhere allows app-a's SGs to be referenced by app-b, or
# vice versa — that cross-reference is what you'll try to add in the
# attack test and watch fail conceptually (SGs can't reference a SG in a
# different VPC at all, which is itself a segmentation guarantee).

# =========================================================================
# IAM — one role per application, least-privilege policy scoped to only
# that app's own S3 bucket. This is what the attack test exploits: App A's
# role trying to touch App B's bucket gets AccessDenied.
# =========================================================================

resource "aws_s3_bucket" "app_a_data" {
  bucket = "app-a-data-bucket"
}

resource "aws_s3_bucket" "app_b_data" {
  bucket = "app-b-data-bucket"
}

resource "aws_iam_role" "app_a_role" {
  name = "app-a-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "app_a_policy" {
  name = "app-a-least-privilege"
  role = aws_iam_role.app_a_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.app_a_data.arn,
        "${aws_s3_bucket.app_a_data.arn}/*"
      ]
      # Deliberately does NOT include app_b_data.arn — this is the
      # boundary the attack test will try (and fail) to cross.
    }]
  })
}

resource "aws_iam_role" "app_b_role" {
  name = "app-b-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "app_b_policy" {
  name = "app-b-least-privilege"
  role = aws_iam_role.app_b_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.app_b_data.arn,
        "${aws_s3_bucket.app_b_data.arn}/*"
      ]
    }]
  })
}

output "app_a_vpc_id"  { value = aws_vpc.app_a.id }
output "app_b_vpc_id"  { value = aws_vpc.app_b.id }
output "app_a_role_arn" { value = aws_iam_role.app_a_role.arn }
output "app_b_role_arn" { value = aws_iam_role.app_b_role.arn }
