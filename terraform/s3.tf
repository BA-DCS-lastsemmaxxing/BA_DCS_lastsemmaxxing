resource "aws_s3_bucket" "s3_frontend" {
  bucket = "${var.project_name}-frontend"
}

resource "aws_s3_bucket_website_configuration" "s3_frontend_website_config" {
  bucket = aws_s3_bucket.s3_frontend.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_policy" "s3_frontend_bucket_policy" {
  bucket = aws_s3_bucket.s3_frontend.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "AllowGetObjects"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.s3_frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.cdn.id}"
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "serverless_bucket_us" {
  bucket = "${var.project_name}-serverless-us"
  provider = aws.us-east-1
}

resource "aws_s3_bucket" "serverless_bucket_ap" {
  bucket = "${var.project_name}-serverless-ap"
}

resource "aws_s3_bucket" "document_storage_bucket" {
  bucket = "${var.project_name}-document-storage"
}