resource "aws_api_gateway_rest_api" "lsm-fyp-api" {
  name        = "${var.project_name}-apigw"
  description = "API Gateway for ${var.project_name}"
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  deployment_id = aws_api_gateway_deployment.prod_deployment.id
}

resource "aws_api_gateway_authorizer" "lsm-fyp-authorizer" {
  name           = "${var.project_name}-authorizer"
  rest_api_id    = aws_api_gateway_rest_api.lsm-fyp-api.id
  type           = "COGNITO_USER_POOLS"
  provider_arns  = [aws_cognito_user_pool.lsm-fyp-user-pool.arn]
}

resource "aws_api_gateway_deployment" "prod_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.lsm-fyp-api.body))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.topics_method_get,
    aws_api_gateway_method.topics_method_post,
    aws_api_gateway_method.topics_method_delete,
    aws_api_gateway_method.documents_method_get,
    aws_api_gateway_method.documents_method_delete,
    aws_api_gateway_method.upload_url_method_get,
    aws_api_gateway_method.download_url_method_get,
    aws_api_gateway_method.documents_corrected_method_get,
    aws_api_gateway_method.feedback_method_post,
    aws_api_gateway_method.retrain_method_post
  ]
}

# Create a resource for /topics
resource "aws_api_gateway_resource" "topics_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
  path_part   = "topics"
}

# Options method for CORS support (GET /topics)
resource "aws_api_gateway_method" "topics_method_options" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.topics_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "topics_method_options_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.topics_resource.id
  http_method = aws_api_gateway_method.topics_method_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"       = true
    "method.response.header.Access-Control-Allow-Methods"      = true
    "method.response.header.Access-Control-Allow-Headers"      = true
    "method.response.header.Access-Control-Allow-Credentials"  = true
  }
}

resource "aws_api_gateway_integration" "topics_options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id             = aws_api_gateway_resource.topics_resource.id
  http_method             = aws_api_gateway_method.topics_method_options.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "topics_method_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.topics_resource.id
  http_method = aws_api_gateway_method.topics_method_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'https://${aws_cloudfront_distribution.cdn.domain_name}'"
    "method.response.header.Access-Control-Allow-Methods"      = "'GET,POST,OPTIONS,DELETE'"
    "method.response.header.Access-Control-Allow-Headers"      = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials"  = "'true'"
  }
}

# GET method for /topics
resource "aws_api_gateway_method" "topics_method_get" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.topics_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

# Trigger fetch topics lambda function when GET method called on /topics
resource "aws_api_gateway_integration" "topics_method_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.topics_resource.id
  http_method = aws_api_gateway_method.topics_method_get.http_method

  type = "AWS_PROXY"
  integration_http_method = "POST"
  uri = aws_lambda_function.fetch_topics_lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "topics_method_get_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.topics_resource.id
    http_method = aws_api_gateway_method.topics_method_get.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "topics_method_get_lambda_permission" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.fetch_topics_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

# POST method for /topics
resource "aws_api_gateway_method" "topics_method_post" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.topics_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id

  request_parameters = {
    "method.request.header.Content-Type" = true
  }
}

# Trigger add new topic lambda function when POST method called on /topics
resource "aws_api_gateway_integration" "topics_method_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id             = aws_api_gateway_resource.topics_resource.id
  http_method             = aws_api_gateway_method.topics_method_post.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.add_new_topic_queue.name}"
  credentials             = aws_iam_role.api_gateway_to_sqs_role.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
  "application/json" = <<EOF
Action=SendMessage&MessageBody=$util.urlEncode($input.body)
EOF
}
}

resource "aws_api_gateway_method_response" "topics_method_post_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.topics_resource.id
    http_method = aws_api_gateway_method.topics_method_post.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "topics_method_post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.topics_resource.id
  http_method = aws_api_gateway_method.topics_method_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'*'"
    "method.response.header.Access-Control-Allow-Methods"     = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

# DELETE method for /topics
resource "aws_api_gateway_method" "topics_method_delete" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.topics_resource.id
  http_method   = "DELETE"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id

  request_parameters = {
    "method.request.header.Content-Type" = true
  }

}

# Trigger remove topic lambda function when DELETE method called on /topics
resource "aws_api_gateway_integration" "topics_method_delete_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id             = aws_api_gateway_resource.topics_resource.id
  http_method             = aws_api_gateway_method.topics_method_delete.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.remove_topic_queue.name}"
  credentials             = aws_iam_role.api_gateway_to_sqs_role.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
  "application/json" = <<EOF
Action=SendMessage&MessageBody=$util.urlEncode($input.body)
EOF
}
}

resource "aws_api_gateway_method_response" "topics_method_delete_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.topics_resource.id
    http_method = aws_api_gateway_method.topics_method_delete.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "topics_method_delete_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.topics_resource.id
  http_method = aws_api_gateway_method.topics_method_delete.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'*'"
    "method.response.header.Access-Control-Allow-Methods"     = "'DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "topics_method_delete_lambda_permission" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.remove_topic_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

# Allow API Gateway to send jobs to the sqs
resource "aws_iam_role" "api_gateway_to_sqs_role" {
  name = "APIGatewayToSQSRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "api_gateway_sqs_policy" {
  name = "APIGatewaySQSSendPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sqs:SendMessage",
      Resource = [
        aws_sqs_queue.add_new_topic_queue.arn,
        aws_sqs_queue.remove_topic_queue.arn,
        aws_sqs_queue.feedback_retraining_queue.arn
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_sqs_attachment" {
  role       = aws_iam_role.api_gateway_to_sqs_role.name
  policy_arn = aws_iam_policy.api_gateway_sqs_policy.arn
}

# Create a resource for /documents
resource "aws_api_gateway_resource" "documents_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
  path_part   = "documents"
}

# Options method for CORS support (GET /documents)
resource "aws_api_gateway_method" "documents_method_options" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.documents_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "documents_method_options_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_resource.id
  http_method = aws_api_gateway_method.documents_method_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"       = true
    "method.response.header.Access-Control-Allow-Methods"      = true
    "method.response.header.Access-Control-Allow-Headers"      = true
    "method.response.header.Access-Control-Allow-Credentials"  = true
  }
}

resource "aws_api_gateway_integration" "documents_options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id             = aws_api_gateway_resource.documents_resource.id
  http_method             = aws_api_gateway_method.documents_method_options.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "documents_method_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_resource.id
  http_method = aws_api_gateway_method.documents_method_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'https://${aws_cloudfront_distribution.cdn.domain_name}'"
    "method.response.header.Access-Control-Allow-Methods"      = "'GET,POST,OPTIONS,DELETE'"
    "method.response.header.Access-Control-Allow-Headers"      = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials"  = "'true'"
  }
}

# GET method for /documents
resource "aws_api_gateway_method" "documents_method_get" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.documents_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

# When using Lambda proxy integration, the HTTP method must be POST
# Trigger fetch documents lambda function when GET method called on /documents
resource "aws_api_gateway_integration" "documents_method_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_resource.id
  http_method = aws_api_gateway_method.documents_method_get.http_method

  type = "AWS_PROXY"
  integration_http_method = "POST"
  uri = aws_lambda_function.fetch_documents_lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "documents_method_get_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.documents_resource.id
    http_method = aws_api_gateway_method.documents_method_get.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "documents_method_get_lambda_permission" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.fetch_documents_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

# DELETE method for /documents
resource "aws_api_gateway_method" "documents_method_delete" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_resource.id
  http_method = "DELETE"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

resource "aws_api_gateway_integration" "documents_method_delete_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_resource.id
  http_method = aws_api_gateway_method.documents_method_delete.http_method

  type = "AWS_PROXY"
  integration_http_method = "POST"
  uri = aws_lambda_function.delete_document_lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "documents_method_delete_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_resource.id
  http_method = aws_api_gateway_method.documents_method_delete.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"       = true
    "method.response.header.Access-Control-Allow-Methods"      = true
    "method.response.header.Access-Control-Allow-Headers"      = true
    "method.response.header.Access-Control-Allow-Credentials"  = true
  }
}

resource "aws_lambda_permission" "documents_method_delete_lambda_permission" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_document_lambda.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

# Create /upload resource
resource "aws_api_gateway_resource" "upload_resource" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
    path_part   = "upload"
}

# Child resource for /documents/corrected
resource "aws_api_gateway_resource" "documents_corrected_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id   = aws_api_gateway_resource.documents_resource.id
  path_part   = "corrected"
}

# Options method for CORS support (GET /documents/corrected)
resource "aws_api_gateway_method" "documents_corrected_method_options" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.documents_corrected_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "documents_corrected_method_options_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_corrected_resource.id
  http_method = aws_api_gateway_method.documents_corrected_method_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"       = true
    "method.response.header.Access-Control-Allow-Methods"      = true
    "method.response.header.Access-Control-Allow-Headers"      = true
    "method.response.header.Access-Control-Allow-Credentials"  = true
  }
}

resource "aws_api_gateway_integration" "documents_corrected_options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id             = aws_api_gateway_resource.documents_corrected_resource.id
  http_method             = aws_api_gateway_method.documents_corrected_method_options.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "documents_corrected_method_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_corrected_resource.id
  http_method = aws_api_gateway_method.documents_corrected_method_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'https://${aws_cloudfront_distribution.cdn.domain_name}'"
    "method.response.header.Access-Control-Allow-Methods"      = "'GET,POST,OPTIONS,DELETE'"
    "method.response.header.Access-Control-Allow-Headers"      = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials"  = "'true'"
  }
}

# GET method for /documents/corrected
resource "aws_api_gateway_method" "documents_corrected_method_get" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.documents_corrected_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

resource "aws_api_gateway_integration" "documents_corrected_method_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_corrected_resource.id
  http_method = aws_api_gateway_method.documents_corrected_method_get.http_method

  type = "AWS_PROXY"
  integration_http_method = "POST"
  uri = aws_lambda_function.fetch_corrected_documents_lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "documents_corrected_method_get_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_corrected_resource.id
  http_method = aws_api_gateway_method.documents_corrected_method_get.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "documents_corrected_method_get_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_corrected_documents_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

# Create /upload/url resource under /upload
resource "aws_api_gateway_resource" "upload_url_resource" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    parent_id   = aws_api_gateway_resource.upload_resource.id
    path_part   = "url"
}

resource "aws_api_gateway_method" "upload_url_method_get" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.upload_url_resource.id
    http_method   = "GET"
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

resource "aws_api_gateway_integration" "upload_url_method_get_integration" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.upload_url_resource.id
    http_method = aws_api_gateway_method.upload_url_method_get.http_method
    
    integration_http_method = "POST" # Always POST for Lambda proxy integration
    type = "AWS_PROXY"
    uri = aws_lambda_function.fetch_upload_url_lambda.invoke_arn
}

resource "aws_lambda_permission" "upload_url_method_get_lambda_permission" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.fetch_upload_url_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

resource "aws_api_gateway_method" "upload_url_method_options" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.upload_url_resource.id
    http_method   = "OPTIONS"
    authorization = "NONE"
}

resource "aws_api_gateway_method_response" "upload_url_method_options_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.upload_url_resource.id
    http_method = aws_api_gateway_method.upload_url_method_options.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
    }
}

resource "aws_api_gateway_integration" "upload_url_options_integration" {
    rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id             = aws_api_gateway_resource.upload_url_resource.id
    http_method             = aws_api_gateway_method.upload_url_method_options.http_method
    type                    = "MOCK"
    request_templates = {
        "application/json" = jsonencode({
            statusCode = 200
        })
    }
}

resource "aws_api_gateway_integration_response" "upload_url_options_integration_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.upload_url_resource.id
    http_method = aws_api_gateway_method.upload_url_method_options.http_method
    status_code = "200"

    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = "'https://${aws_cloudfront_distribution.cdn.domain_name}'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
        "method.response.header.Access-Control-Allow-Credentials" = "'true'"
    }
}

# Create /download resource
resource "aws_api_gateway_resource" "download_resource" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
    path_part   = "download"
}

# Create /download/url resource under /download
resource "aws_api_gateway_resource" "download_url_resource" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    parent_id   = aws_api_gateway_resource.download_resource.id
    path_part   = "url"
}

resource "aws_api_gateway_method" "download_url_method_get" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.download_url_resource.id
    http_method   = "GET"
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

resource "aws_api_gateway_integration" "download_url_method_get_integration" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.download_url_resource.id
    http_method = aws_api_gateway_method.download_url_method_get.http_method
    
    integration_http_method = "POST" # Always POST for Lambda proxy integration
    type = "AWS_PROXY"
    uri = aws_lambda_function.fetch_download_url_lambda.invoke_arn
}

resource "aws_lambda_permission" "download_url_method_get_lambda_permission" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.fetch_download_url_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

resource "aws_api_gateway_method" "download_url_method_options" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.download_url_resource.id
    http_method   = "OPTIONS"
    authorization = "NONE"
}

resource "aws_api_gateway_method_response" "download_url_method_options_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.download_url_resource.id
    http_method = aws_api_gateway_method.download_url_method_options.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
    }
}

resource "aws_api_gateway_integration" "download_url_options_integration" {
    rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id             = aws_api_gateway_resource.download_url_resource.id
    http_method             = aws_api_gateway_method.download_url_method_options.http_method
    type                    = "MOCK"
    request_templates = {
        "application/json" = jsonencode({
            statusCode = 200
        })
    }
}

resource "aws_api_gateway_integration_response" "download_url_options_integration_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.download_url_resource.id
    http_method = aws_api_gateway_method.download_url_method_options.http_method
    status_code = "200"

    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = "'https://${aws_cloudfront_distribution.cdn.domain_name}'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
        "method.response.header.Access-Control-Allow-Credentials" = "'true'"
    }
}

# Create /feedback resource
# OPTIONS for /feedback
resource "aws_api_gateway_resource" "feedback_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
  path_part = "feedback"
}

resource "aws_api_gateway_method" "feedback_method_options" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.feedback_resource.id
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "feedback_method_options_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.feedback_resource.id
    http_method = aws_api_gateway_method.feedback_method_options.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
    }
}

resource "aws_api_gateway_integration" "feedback_options_integration" {
    rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id             = aws_api_gateway_resource.feedback_resource.id
    http_method             = aws_api_gateway_method.feedback_method_options.http_method
    type                    = "MOCK"
    request_templates = {
        "application/json" = jsonencode({
            statusCode = 200
        })
    }
}

resource "aws_api_gateway_integration_response" "feedback_options_integration_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.feedback_resource.id
    http_method = aws_api_gateway_method.feedback_method_options.http_method
    status_code = "200"

    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = "'https://${aws_cloudfront_distribution.cdn.domain_name}'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
        "method.response.header.Access-Control-Allow-Credentials" = "'true'"
    }
}

# POST for /feedback
resource "aws_api_gateway_method" "feedback_method_post" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.feedback_resource.id
  http_method = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

resource "aws_api_gateway_integration" "feedback_method_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.feedback_resource.id
  http_method = aws_api_gateway_method.feedback_method_post.http_method

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.send_feedback_lambda.invoke_arn
}

resource "aws_lambda_permission" "feedback_method_post_lambda_permission" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.send_feedback_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

# Create a resource for /retrain
resource "aws_api_gateway_resource" "retrain_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
  path_part   = "retrain"
}

# Options method for CORS support (GET /retrain)
resource "aws_api_gateway_method" "retrain_method_options" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.retrain_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "retrain_method_options_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.retrain_resource.id
  http_method = aws_api_gateway_method.retrain_method_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"       = true
    "method.response.header.Access-Control-Allow-Methods"      = true
    "method.response.header.Access-Control-Allow-Headers"      = true
    "method.response.header.Access-Control-Allow-Credentials"  = true
  }
}

resource "aws_api_gateway_integration" "retrain_options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id             = aws_api_gateway_resource.retrain_resource.id
  http_method             = aws_api_gateway_method.retrain_method_options.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "retrain_method_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.retrain_resource.id
  http_method = aws_api_gateway_method.retrain_method_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'https://${aws_cloudfront_distribution.cdn.domain_name}'"
    "method.response.header.Access-Control-Allow-Methods"      = "'GET,POST,OPTIONS,DELETE'"
    "method.response.header.Access-Control-Allow-Headers"      = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials"  = "'true'"
  }
}

# POST method for /retrain
resource "aws_api_gateway_method" "retrain_method_post" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.retrain_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id

  request_parameters = {
    "method.request.header.Content-Type" = true
  }
}

# Trigger feedback retraining lambda function when POST method called on /retrain
resource "aws_api_gateway_integration" "retrain_method_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id             = aws_api_gateway_resource.retrain_resource.id
  http_method             = aws_api_gateway_method.retrain_method_post.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.feedback_retraining_queue.name}"
  credentials             = aws_iam_role.api_gateway_to_sqs_role.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
  "application/json" = <<EOF
Action=SendMessage&MessageBody=$util.urlEncode($input.body)
EOF
}
}

resource "aws_api_gateway_method_response" "retrain_method_post_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.retrain_resource.id
    http_method = aws_api_gateway_method.retrain_method_post.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "retrain_method_post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.retrain_resource.id
  http_method = aws_api_gateway_method.retrain_method_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'*'"
    "method.response.header.Access-Control-Allow-Methods"     = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
}