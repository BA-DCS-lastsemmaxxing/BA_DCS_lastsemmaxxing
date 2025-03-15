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

resource "aws_s3_bucket_versioning" "serverless_bucket_versioning_ap" {
  bucket = aws_s3_bucket.serverless_bucket_ap.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "document_storage_bucket" {
  bucket = "${var.project_name}-document-storage"
}

resource "aws_lambda_permission" "allow_s3_trigger" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.document_storage_bucket.arn
}

resource "aws_s3_bucket_notification" "file_upload_trigger" {
  bucket = aws_s3_bucket.document_storage_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_cors_configuration" "cors" {
  bucket = aws_s3_bucket.document_storage_bucket.id

  cors_rule {
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "allow_presigned_uploads" {
  bucket = aws_s3_bucket.document_storage_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.document_storage_bucket.id}/*"
        Condition = {
          StringLike = {
            "aws:Referer" = ["https://d1ztk01ovm0zc3.cloudfront.net"]
          }
        }
      }
    ]
  })
}

// db init script 
resource "aws_s3_object" "db_init_script" {
  bucket = aws_s3_bucket.serverless_bucket_ap.bucket
  key = "rds_init_script.sql"
  source = "${path.module}/../mysql/lsm_fyp.sql"
}

// Lambda Layer
data "aws_s3_object" "lambda_layer" {
  bucket = aws_s3_bucket.serverless_bucket_ap.bucket
  key = "lambda_layer.zip"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  layer_name = "Lambda_Layer"
  s3_bucket  = aws_s3_bucket.serverless_bucket_ap.bucket
  s3_key     = "lambda_layer.zip"

  source_code_hash = data.aws_s3_object.lambda_layer.etag
}

// Add Lambda Function Zips as objects here
data "aws_s3_object" "auth_lambda_zip" {
  provider = aws.us-east-1
  bucket = aws_s3_bucket.serverless_bucket_us.bucket
  key = "auth_lambda.zip"
}

data "aws_s3_object" "fetch_documents_lambda_zip" {
  bucket = aws_s3_bucket.serverless_bucket_ap.bucket
  key = "fetch_documents.zip"
}

data "aws_s3_object" "fetch_upload_url_lambda_zip" {
  bucket = aws_s3_bucket.serverless_bucket_ap.bucket
  key = "fetch_upload_url.zip"
}

data "aws_s3_object" "insert_rds_new_document_lambda_zip" {
  bucket = aws_s3_bucket.serverless_bucket_ap.bucket
  key = "insert_rds_new_document.zip"
}

data "aws_s3_object" "s3_trigger_lambda_zip" {
  bucket = aws_s3_bucket.serverless_bucket_ap.bucket
  key = "s3_trigger.zip"
}