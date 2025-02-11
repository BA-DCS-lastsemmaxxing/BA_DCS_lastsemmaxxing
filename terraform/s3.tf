data "aws_s3_bucket" "existing" {
  bucket = var.s3_name
}

resource "aws_s3_bucket" "s3" {
  for_each = data.aws_s3_bucket.existing.id != "" ? {} : { "create" = true }

  bucket = var.s3_name
}

resource "aws_s3_bucket_public_access_block" "s3" {
  for_each = aws_s3_bucket.s3
  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "s3" {
  for_each = aws_s3_bucket.s3
  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "AllowGetObjects"
    Statement = [
      {
        Sid       = "AllowPublic"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${each.value.arn}/**"
      }
    ]
  })
}
