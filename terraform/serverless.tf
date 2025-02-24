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
    s3_bucket = "${var.project_name}-serverless"
    s3_key = "auth_lambda.zip"
    function_name = "auth_lambda_edge"
    role = aws_iam_role.lambda_edge_role.arn
    handler = "auth_lambda.lambda_handler"
    runtime = "python3.8"
    publish = true
}