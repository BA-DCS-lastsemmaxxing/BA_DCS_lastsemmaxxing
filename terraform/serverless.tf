locals {
    rds_credentials = jsondecode(data.aws_ssm_parameter.db_credentials.value)

    lambda_db_variables = {
        DB_HOST = aws_db_instance.rds.address
        DB_USER = local.rds_credentials.username
        DB_PASSWORD = local.rds_credentials.password
        DB_NAME = aws_db_instance.rds.db_name
    }
}

# ECR Repository
resource "aws_ecr_repository" "lsm_fyp_repo" {
  name = "${var.project_name}-repo"
}

# Security Group for Lambda Functions
resource "aws_security_group" "lambda_sg" {
  name = "lambda-sg"
  vpc_id = aws_vpc.private_vpc.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.rds_sg.id] # Allow outbound connection to rds sg
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Lambda Security Group"
  }
}

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
      {
        Effect   = "Allow",
        Action   = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:CreateModelInvocationJob"
        ],
        Resource = "*"
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
      },
      # Allow to receive messages from sqs
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = [
          aws_sqs_queue.add_new_topic_queue.arn,
          aws_sqs_queue.remove_topic_queue.arn,
          aws_sqs_queue.feedback_retraining_queue.arn
        ]
      }
    ]
  })
}

# Delete Document Function
resource "aws_lambda_function" "delete_document_lambda" {
  function_name = "delete_document"

  runtime = "python3.9"
  handler = "delete_document.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "delete_document.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.delete_document_lambda_zip.etag

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = merge(
      local.lambda_db_variables,
      {
        S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
      }
    )
  }
}

resource "aws_cloudwatch_log_group" "delete_document_lambda_logs" {
  name = "/aws/lambda/${aws_lambda_function.delete_document_lambda.function_name}"
  retention_in_days = 7
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

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = local.lambda_db_variables
  }
}

resource "aws_cloudwatch_log_group" "fetch_documents_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_documents_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

# Fetch Corrected Documents Function
resource "aws_lambda_function" "fetch_corrected_documents_lambda" {
  function_name = "fetch_corrected_documents"

  runtime = "python3.9"
  handler = "fetch_corrected_documents.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "fetch_corrected_documents.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.fetch_corrected_documents_lambda_zip.etag

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = local.lambda_db_variables
  }
}

resource "aws_cloudwatch_log_group" "fetch_corrected_documents_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_corrected_documents_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
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

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    }
  }
}

resource "aws_cloudwatch_log_group" "fetch_upload_url_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_upload_url_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

# Fetch download url function
resource "aws_lambda_function" "fetch_download_url_lambda" {
  function_name = "fetch_download_url"

  runtime = "python3.9"
  handler = "fetch_download_url.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "fetch_download_url.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.fetch_download_url_lambda_zip.etag
  
  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    }
  }
}

resource "aws_cloudwatch_log_group" "fetch_download_url_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_download_url_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
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

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = local.lambda_db_variables
  }
}

resource "aws_cloudwatch_log_group" "insert_rds_new_document_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.insert_rds_new_document_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
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

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      STEP_FUNCTION_ARN = aws_sfn_state_machine.s3_workflow.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "s3_trigger_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.s3_trigger_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

# Send Feedback Lambda
resource "aws_lambda_function" "send_feedback_lambda" {
  function_name = "send_feedback"
  
  runtime = "python3.9"
  handler = "send_feedback.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "send_feedback.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.send_feedback_lambda_zip.etag

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = local.lambda_db_variables
  }
}

resource "aws_cloudwatch_log_group" "send_feedback_lambda_logs" {
  name = "/aws/lambda/${aws_lambda_function.send_feedback_lambda.function_name}"
  retention_in_days = 7
}

# Document classification lambda
resource "aws_lambda_function" "document_classification_lambda" {
  function_name = "document_classification"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lsm_fyp_repo.repository_url}:latest"
  timeout       = 900
  memory_size   = 2000
  role = aws_iam_role.lambda_execution_role.arn

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  
  image_config {
    command     = ["document_classification.lambda_handler"]
  }

  environment {
    variables = merge(local.lambda_db_variables, {
      REGION = var.region
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    })
  }
}

resource "aws_cloudwatch_log_group" "document_classification_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.document_classification_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

# Add new topic lambda
resource "aws_lambda_function" "add_new_topic_lambda" {
  function_name = "add_new_topic"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lsm_fyp_repo.repository_url}:latest"
  timeout       = 900
  memory_size   = 2000
  role = aws_iam_role.lambda_execution_role.arn
  
  image_config {
    command     = ["new_topic.lambda_handler"]
  }

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = merge(local.lambda_db_variables, {
      REGION = var.region
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    })
  }
}

resource "aws_cloudwatch_log_group" "add_new_topic_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.add_new_topic_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

# Remove topic lambda
resource "aws_lambda_function" "remove_topic_lambda" {
  function_name = "remove_topic"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lsm_fyp_repo.repository_url}:latest"
  timeout       = 900
  memory_size   = 2000
  role = aws_iam_role.lambda_execution_role.arn

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  
  image_config {
    command     = ["remove_topic.lambda_handler"]
  }

  environment {
    variables = merge(local.lambda_db_variables, {
      REGION = var.region
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    })
  }
}

resource "aws_cloudwatch_log_group" "remove_topic_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.remove_topic_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

# Add new topic lambda
resource "aws_lambda_function" "feedback_retraining_lambda" {
  function_name = "feedback_retraining"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lsm_fyp_repo.repository_url}:latest"
  timeout       = 900
  memory_size   = 2000
  role = aws_iam_role.lambda_execution_role.arn

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  
  image_config {
    command     = ["feedback_retraining.lambda_handler"]
  }

  environment {
    variables = merge(local.lambda_db_variables, {
      REGION = var.region
      S3_BUCKET = aws_s3_bucket.document_storage_bucket.bucket
    })
  }
}

resource "aws_cloudwatch_log_group" "feedback_retraining_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.feedback_retraining_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

# Fetch topics function
resource "aws_lambda_function" "fetch_topics_lambda" {
  function_name = "fetch_topics"

  runtime = "python3.9"
  handler = "fetch_topics.lambda_handler"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key = "fetch_topics.zip"

  role = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.fetch_topics_lambda_zip.etag

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = local.lambda_db_variables
  }
}

resource "aws_cloudwatch_log_group" "fetch_topics_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_topics_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn

  depends_on = [aws_iam_role.lambda_execution_role, aws_iam_policy.lambda_policy]
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

  depends_on = [aws_iam_role.lambda_execution_role]
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

  depends_on = [ aws_iam_role.lambda_edge_role ]
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

resource "aws_cloudwatch_log_group" "auth_lambda_edge_logs" {
  provider          = aws.us-east-1
  name              = "/aws/lambda/${aws_lambda_function.rds_init_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
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

  depends_on = [ aws_iam_role.step_function_role, aws_iam_policy.step_function_policy ]
}

# db init lambda iam
resource "aws_iam_role" "rds_init_lambda_role" {
  name = "rds_init_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "rds_init_lambda_policy" {
  name        = "rds_init_lambda_policy"
  description = "Policy for Lambda to access S3, RDS, SSM, and Logs"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "${aws_s3_bucket.serverless_bucket_ap.arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:*:*:parameter/rds/db_host",
        "arn:aws:ssm:*:*:parameter/rds/db_user",
        "arn:aws:ssm:*:*:parameter/rds/db_pass"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.rds_init_lambda_role.name
  policy_arn = aws_iam_policy.rds_init_lambda_policy.arn

  depends_on = [aws_iam_role.rds_init_lambda_role, aws_iam_policy.rds_init_lambda_policy]
}

resource "aws_lambda_function" "rds_init_lambda" {
  function_name = "rds_init_lambda"
  runtime = "python3.9"
  handler = "rds_init.lambda_handler"
  s3_bucket = aws_s3_bucket.serverless_bucket_ap.bucket
  s3_key = "rds_init.zip"
  role = aws_iam_role.rds_init_lambda_role.arn
  source_code_hash = data.aws_s3_object.rds_init_lambda_zip.etag

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  vpc_config {
    subnet_ids = [ aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = merge(
      local.lambda_db_variables,
      {
        S3_BUCKET = aws_s3_bucket.serverless_bucket_ap.bucket,
        SQL_FILE_KEY = "rds_init_script.sql"
      }
    )
  }
}

resource "aws_cloudwatch_log_group" "rds_init_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.rds_init_lambda.function_name}"
  retention_in_days = 7  # Adjust retention as needed
}

resource "aws_sqs_queue" "add_new_topic_queue" {
  name = "add-new-topic-queue"
  visibility_timeout_seconds = 910
}

resource "aws_lambda_event_source_mapping" "add_new_topic_queue_mapping" {
  event_source_arn = aws_sqs_queue.add_new_topic_queue.arn
  function_name    = aws_lambda_function.add_new_topic_lambda.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_sqs_queue" "remove_topic_queue" {
  name = "remove-topic-queue"
  visibility_timeout_seconds = 910
}

resource "aws_lambda_event_source_mapping" "remove_topic_queue_mapping" {
  event_source_arn = aws_sqs_queue.remove_topic_queue.arn
  function_name    = aws_lambda_function.remove_topic_lambda.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_sqs_queue" "feedback_retraining_queue" {
  name = "feedback-retraining-queue"
  visibility_timeout_seconds = 910
}

resource "aws_lambda_event_source_mapping" "feedback_retraining_queue_mapping" {
  event_source_arn = aws_sqs_queue.feedback_retraining_queue.arn
  function_name    = aws_lambda_function.feedback_retraining_lambda.arn
  batch_size       = 1
  enabled          = true
}