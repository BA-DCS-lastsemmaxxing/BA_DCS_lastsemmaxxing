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
          "s3:DeleteObject",  # Added for delete document
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
      {
        Effect   = "Allow",
        Action   = "states:StartExecution",
        Resource = aws_sfn_state_machine.s3_workflow.arn
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

# Fetch Documents Function
resource "aws_lambda_function" "fetch_documents_lambda" {
  function_name = "fetch_documents"

  runtime = "python3.9"
  handler = "fetch_documents.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "fetch_documents.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.fetch_documents_lambda_zip.etag

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  environment {
    variables = {
      DB_HOST = "lsm-fyp-rds.cpk00i8mcpir.ap-southeast-1.rds.amazonaws.com"
      DB_USER = "admin"
      DB_PASSWORD = "testpassword"
      DB_NAME = "lsm_fyp"
    }
  }
}

# Fetch upload url function
resource "aws_lambda_function" "fetch_upload_url_lambda" {
  function_name = "fetch_upload_url"

  runtime = "python3.9"
  handler = "fetch_upload_url.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "fetch_upload_url.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.fetch_upload_url_lambda_zip.etag

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    }
  }
}

# Insert new document into RDS function
resource "aws_lambda_function" "insert_rds_new_document_lambda" {
  function_name = "insert_rds_new_document"

  runtime = "python3.9"
  handler = "insert_rds_new_document.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "insert_rds_new_document.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.insert_rds_new_document_lambda_zip.etag

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  environment {
    variables = {
      DB_HOST = "lsm-fyp-rds.cpk00i8mcpir.ap-southeast-1.rds.amazonaws.com"
      DB_USER = "admin"
      DB_PASSWORD = "testpassword"
      DB_NAME = "lsm_fyp"
    }
  }
}

# Lambda function triggered on new object in S3
resource "aws_lambda_function" "s3_trigger_lambda" {
  function_name = "s3_trigger"

  runtime = "python3.9"
  handler = "s3_trigger.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "s3_trigger.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.s3_trigger_lambda_zip.etag

  environment {
    variables = {
      STEP_FUNCTION_ARN = aws_sfn_state_machine.s3_workflow.arn
    }
  }
}

# Document classification lambda
resource "aws_lambda_function" "document_classification_lambda" {
  function_name = "document_classification"
  timeout = 30
  runtime = "python3.9"
  handler = "document_classification.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "document_classification.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.document_classification_lambda_zip.etag

  layers = [
    aws_lambda_layer_version.lambda_layer.arn,
    aws_lambda_layer_version.document_classification_dependencies.arn]

  environment {
    variables = {
      DB_HOST = "lsm-fyp-rds.cpk00i8mcpir.ap-southeast-1.rds.amazonaws.com"
      DB_USER = "admin"
      DB_PASSWORD = "testpassword"
      DB_NAME = "lsm_fyp"
      REGION = var.region
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket

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

# Document processing workflow
resource "aws_sfn_state_machine" "s3_workflow" {
  name     = "s3-file-processing-workflow"
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
  {
    "Comment": "Workflow to process uploaded files",
    "StartAt": "InsertIntoRDS",
    "States": {
      "InsertIntoRDS": {
        "Type": "Task",
        "Resource": "${aws_lambda_function.insert_rds_new_document_lambda.arn}",
        "Next": "ProcessDocument"
      },
      "ProcessDocument": {
        "Type": "Task",
        "Resource": "${aws_lambda_function.document_classification_lambda.arn}",
        "End": true
      }
    }
  }
  EOF
}

# IAM role for step function
resource "aws_iam_role" "step_function_role" {
  name = "StepFunctionsExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "step_function_policy" {
  name        = "StepFunctionsLambdaInvokePolicy"
  description = "Allows Step Functions to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.insert_rds_new_document_lambda.arn,
          aws_lambda_function.document_classification_lambda.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  policy_arn = aws_iam_policy.step_function_policy.arn
  role       = aws_iam_role.step_function_role.name
}

