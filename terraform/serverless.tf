locals {
  rds_credentials = jsondecode(data.aws_ssm_parameter.db_credentials.value)

  lambda_functions = {
    delete_document = "delete_document.lambda_handler",
    fetch_documents = "fetch_documents.lambda_handler",
    fetch_corrected_documents = "fetch_corrected_documents.lambda_handler",
    fetch_upload_url = "fetch_upload_url.lambda_handler",
    fetch_download_url = "fetch_download_url.lambda_handler",
    insert_rds_new_document = "insert_rds_new_document.lambda_handler",
    s3_trigger = "s3_trigger.lambda_handler",
    send_feedback = "send_feedback.lambda_handler",
    fetch_topics = "fetch_topics.lambda_handler",
  }
}

# ECR Repository
resource "aws_ecr_repository" "lsm_fyp_repo" {
  name = "${var.project_name}-repo"
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
  name        = "${var.project_name}-lambda-policy"
  description = "Allow Lambda to access other AWS resources"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # S3 and RDS access
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject", # Added for delete document
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
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:CreateModelInvocationJob"
        ],
        Resource = "*"
      },
      # CloudWatch Logs Access
      {
        Effect = "Allow",
        Action = [
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
      },
      # Allow network interface creation
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Functions from S3 Zips
resource "aws_lambda_function" "zip_lambdas" {
  for_each = local.lambda_functions

  function_name = each.key
  handler = each.value
  runtime = "python3.9"

  s3_bucket = "${var.project_name}-serverless-ap"
  s3_key    = "${each.key}.zip"

  role             = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.aws_s3_object.lambda_zips[each.key].etag

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  environment {
    variables = {
      DB_HOST     = aws_db_instance.rds.address
      DB_USER     = local.rds_credentials.username
      DB_PASSWORD = local.rds_credentials.password
      DB_NAME     = aws_db_instance.rds.db_name
      S3_BUCKET   = aws_s3_bucket.document_storage_bucket.bucket
    }
  }
}

# Document classification lambda
resource "aws_lambda_function" "document_classification_lambda" {
  function_name = "document_classification"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lsm_fyp_repo.repository_url}:latest"
  timeout       = 900
  memory_size   = 2000
  role          = aws_iam_role.lambda_execution_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  image_config {
    command = ["document_classification.lambda_handler"]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.rds.address
      DB_USER     = local.rds_credentials.username
      DB_PASSWORD = local.rds_credentials.password
      DB_NAME     = aws_db_instance.rds.db_name
      REGION      = var.region
      S3_BUCKET   = aws_s3_bucket.document_storage_bucket.bucket
    }
  }

  depends_on = [ aws_iam_role_policy_attachment.lambda_policy_attachment, aws_iam_role_policy_attachment.lambda_basic_execution ]
}

# Add new topic lambda
resource "aws_lambda_function" "add_new_topic_lambda" {
  function_name = "add_new_topic"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lsm_fyp_repo.repository_url}:latest"
  timeout       = 900
  memory_size   = 2000
  role          = aws_iam_role.lambda_execution_role.arn

  image_config {
    command = ["new_topic.lambda_handler"]
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.rds.address
      DB_USER     = local.rds_credentials.username
      DB_PASSWORD = local.rds_credentials.password
      DB_NAME     = aws_db_instance.rds.db_name
      REGION      = var.region
      S3_BUCKET   = aws_s3_bucket.document_storage_bucket.bucket
    }
  }

  depends_on = [ aws_iam_role_policy_attachment.lambda_policy_attachment, aws_iam_role_policy_attachment.lambda_basic_execution ]
}

# Remove topic lambda
resource "aws_lambda_function" "remove_topic_lambda" {
  function_name = "remove_topic"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lsm_fyp_repo.repository_url}:latest"
  timeout       = 900
  memory_size   = 2000
  role          = aws_iam_role.lambda_execution_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  image_config {
    command = ["remove_topic.lambda_handler"]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.rds.address
      DB_USER     = local.rds_credentials.username
      DB_PASSWORD = local.rds_credentials.password
      DB_NAME     = aws_db_instance.rds.db_name
      REGION      = var.region
      S3_BUCKET   = aws_s3_bucket.document_storage_bucket.bucket
    }
  }

  depends_on = [ aws_iam_role_policy_attachment.lambda_policy_attachment, aws_iam_role_policy_attachment.lambda_basic_execution ]
}

# Add new topic lambda
resource "aws_lambda_function" "feedback_retraining_lambda" {
  function_name = "feedback_retraining"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lsm_fyp_repo.repository_url}:latest"
  timeout       = 900
  memory_size   = 2000
  role          = aws_iam_role.lambda_execution_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  image_config {
    command = ["feedback_retraining.lambda_handler"]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.rds.address
      DB_USER     = local.rds_credentials.username
      DB_PASSWORD = local.rds_credentials.password
      DB_NAME     = aws_db_instance.rds.db_name
      REGION      = var.region
      S3_BUCKET   = aws_s3_bucket.document_storage_bucket.bucket
    }
  }

  depends_on = [ aws_iam_role_policy_attachment.lambda_policy_attachment, aws_iam_role_policy_attachment.lambda_basic_execution ]
}

# Code for Lambda Edge Function - Lambda Authoriser
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_iam_role" "lambda_edge_role" {
  provider = aws.us-east-1
  name     = "lambda-edge-role"
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

  depends_on = [aws_iam_role.lambda_edge_role]
}

resource "aws_lambda_function" "auth_lambda_edge" {
  provider      = aws.us-east-1
  s3_bucket     = "${var.project_name}-serverless-us"
  s3_key        = "auth_lambda.zip"
  function_name = "auth_lambda_edge"
  role          = aws_iam_role.lambda_edge_role.arn
  handler       = "auth_lambda.lambda_handler"
  runtime       = "python3.9"
  publish       = true

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
        "Resource": "${aws_lambda_function.zip_lambdas["insert_rds_new_document_lambda"].arn}",
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
          aws_lambda_function.zip_lambdas["insert_rds_new_document_lambda"].arn,
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

  depends_on = [aws_iam_role.step_function_role, aws_iam_policy.step_function_policy]
}

resource "aws_iam_policy" "lambda_sfn_policy" {
  name        = "${var.project_name}-lambda-sfn-policy"
  description = "Allow Lambda to start Step Functions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "states:StartExecution",
        Resource = aws_sfn_state_machine.s3_workflow.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sfn_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_sfn_policy.arn
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
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.serverless_bucket_ap.arn}/*",
        "${aws_s3_bucket.serverless_bucket_ap.arn}"
      ]
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
    },
    {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        "Resource" : "*"
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
  function_name    = "rds_init_lambda"
  runtime          = "python3.9"
  handler          = "rds_init.lambda_handler"
  s3_bucket        = aws_s3_bucket.serverless_bucket_ap.bucket
  s3_key           = "rds_init.zip"
  role             = aws_iam_role.rds_init_lambda_role.arn
  source_code_hash = data.aws_s3_object.rds_init_lambda_zip.etag
  timeout          = 30

  layers = [aws_lambda_layer_version.lambda_layer.arn]

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST      = aws_db_instance.rds.address,
      DB_USER      = local.rds_credentials.username,
      DB_PASSWORD  = local.rds_credentials.password,
      DB_NAME      = aws_db_instance.rds.db_name,
      S3_BUCKET    = aws_s3_bucket.serverless_bucket_ap.bucket
      SQL_FILE_KEY = "rds_init_script.sql"
    }
  }
}
