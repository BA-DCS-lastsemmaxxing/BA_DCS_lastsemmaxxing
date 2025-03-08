resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}-lambda-policy"
  description = "Allow Lambda to access other AWS resources"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # S3 and RDS access
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:PutObjectAcl",
          "s3:GetObjectAcl",
          "rds-db:connect",
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction",
          "execute-api:Invoke"
        ]
        Resource = [
          "${aws_s3_bucket.serverless_bucket_ap.arn}/*",
          "${aws_s3_bucket.document_storage_bucket.arn}/*",
          "${aws_db_instance.rds.arn}/*",
          "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*"
        ]
      },
      # CloudWatch Logs Access
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ap-southeast-1:874280117166:*"
      }
    ]
  })
}

resource "aws_lambda_function" "fetch_documents_lambda" {
  function_name = "fetch_documents"
  runtime       = "python3.9"
  handler       = "fetch_documents.lambda_handler"
  s3_bucket     = "${var.project_name}-serverless-ap"
  s3_key        = "fetch_documents.zip"
  role          = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.fetch_documents_lambda_zip.etag
  layers = [aws_lambda_layer_version.lambda_layer.arn]

  environment {
    variables = {
      DB_HOST     = "lsm-fyp-rds.cpk00i8mcpir.ap-southeast-1.rds.amazonaws.com"
      DB_USER     = "admin"
      DB_PASSWORD = "testpassword"
      DB_NAME     = "lsm_fyp"
    }
  }
}

resource "aws_lambda_function" "fetch_upload_url_lambda" {
  function_name = "fetch_upload_url"
  runtime       = "python3.9"
  handler       = "fetch_upload_url.lambda_handler"
  s3_bucket     = "${var.project_name}-serverless-ap"
  s3_key        = "fetch_upload_url.zip"
  role          = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.fetch_upload_url_lambda_zip.etag

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    }
  }
}

resource "aws_lambda_function" "delete_document_lambda_new" {  # Renamed
  function_name = "delete_document"
  runtime       = "python3.9"
  handler       = "delete_document.lambda_handler"
  s3_bucket     = "${var.project_name}-serverless-ap"
  s3_key        = "delete_document.zip"
  role          = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.delete_document_lambda_zip.etag

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_new" {  # Renamed
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
