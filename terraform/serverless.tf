resource "aws_iam_role" "lambda_execution_role" {
    name = "${var.project_name}-lambda-execution-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Principal = {
                    Service = "lambda.amazonaws.com"
                },
                Action = "sts:AssumeRole"
            }
        ]
    })
}

# Allow Lambda to access other AWS resources
resource "aws_iam_policy" "lambda_policy" {
    name = "${var.project_name}-lambda-policy"
    description = "Allow Lambda to access other AWS resources"
    policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # S3 and RDS access
      {
        Effect   = "Allow",
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
        ],
        Resource = [
          "${aws_s3_bucket.serverless_bucket_ap.arn}",
          "${aws_s3_bucket.serverless_bucket_ap.arn}/*",
          "${aws_s3_bucket.document_storage_bucket.arn}",
          "${aws_s3_bucket.document_storage_bucket.arn}/*",
          "${aws_db_instance.rds.arn}",
          "${aws_db_instance.rds.arn}/*",
          "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*"
        ]
      },
      # CloudWatch Logs Access
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:ap-southeast-1:874280117166:*"
      }
    ]
  })
}

# NOTE: The approach of source_code_hash used here only supports zip files up to 5MB large
# Fetch Documents Function
resource "aws_lambda_function" "fetch_documents_lambda" {
  function_name = "fetch_documents"

  runtime = "python3.9"
  handler = "fetch_documents.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "fetch_documents.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.fetch_documents_lambda_zip.etag
}

# Upload Document Function
resource "aws_lambda_function" "upload_document_lambda" {
  function_name = "upload_document"

  runtime = "python3.9"
  handler = "upload_document.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "upload_document.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.upload_document_lambda_zip.etag

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.document_storage_bucket.bucket
      ORIGIN = aws_cloudfront_distribution.cdn.domain_name
    }
  }
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
    role = aws_iam_role.lambda_execution_role.name
    policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
    role = aws_iam_role.lambda_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Code for Lambda Edge Function - Lambda Authoriser
provider "aws" {
    alias = "us-east-1"
    region = "us-east-1"
}

resource "aws_iam_role" "lambda_edge_role" {
    provider = aws.us-east-1
    name = "lambda-edge-role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "edgelambda.amazonaws.com"
        }
      },
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
            Service = "cloudfront.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_edge_policy_attach" {
  provider   = aws.us-east-1
  name       = "lambda-edge-policy-attach"
  roles      = [aws_iam_role.lambda_edge_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "auth_lambda_edge" {
    provider = aws.us-east-1
    s3_bucket = "${var.project_name}-serverless-us"
    s3_key = "auth_lambda.zip"
    function_name = "auth_lambda_edge"
    role = aws_iam_role.lambda_edge_role.arn
    handler = "auth_lambda.lambda_handler"
    runtime = "python3.9"
    publish = true

    source_code_hash = data.aws_s3_object.auth_lambda_zip.etag
}