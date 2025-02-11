// use this for creating a new bucket
# resource "aws_s3_bucket" "s3" {
#   bucket = var.project_name
# }

// use this for using an existing bucket
data "aws_s3_bucket" "s3" {
  bucket = "lsm-fyp"
}

resource "aws_s3_bucket_website_configuration" "this" {
  // bucket = aws_s3_bucket.s3.bucket
  bucket = data.aws_s3_bucket.s3

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_public_access_block" "s3" {
  // bucket = aws_s3_bucket.s3.bucket
  bucket = data.aws_s3_bucket.s3

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "s3" {
  // bucket = aws_s3_bucket.s3.bucket
  bucket = data.aws_s3_bucket.s3

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "AllowGetObjects"
    Statement = [
      {
        Sid       = "AllowPublic"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        # Resource  = "${aws_s3_bucket.s3.arn}/**"
        Resource  = "${data.aws_s3_bucket.s3.arn}/**"
      }
    ]
  })
}
