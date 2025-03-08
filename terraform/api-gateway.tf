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
    redeployment = sha1(jsonencode(
      aws_api_gateway_rest_api.lsm-fyp-api
    ))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.documents_method_get,
    aws_api_gateway_method.documents_method_options,
    aws_api_gateway_method.upload_method_post,
    aws_api_gateway_method.upload_method_options,
    aws_api_gateway_method.delete_document_method_delete
  ]
}

# Create a resource for /documents
resource "aws_api_gateway_resource" "documents_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
  path_part   = "documents"
}

# GET method for /documents
resource "aws_api_gateway_method" "documents_method_get" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.documents_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

# Integration for GET /documents (fetch documents)
resource "aws_api_gateway_integration" "documents_method_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.documents_resource.id
  http_method = aws_api_gateway_method.documents_method_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.fetch_documents_lambda.invoke_arn
}

# POST method for /upload (upload document)
resource "aws_api_gateway_resource" "upload_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_method_post" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.upload_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

# Integration for POST /upload (upload document)
resource "aws_api_gateway_integration" "upload_method_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.upload_resource.id
  http_method = aws_api_gateway_method.upload_method_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload_document_lambda.invoke_arn
}

# DELETE method for /documents/{document_id} (delete document)
resource "aws_api_gateway_resource" "delete_document_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
  path_part   = "documents"
}

resource "aws_api_gateway_resource" "delete_document_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  parent_id   = aws_api_gateway_resource.delete_document_resource.id
  path_part   = "{document_id}"
}

resource "aws_api_gateway_method" "delete_document_method_delete" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.delete_document_id_resource.id
  http_method   = "DELETE"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

# Integration for DELETE /documents/{document_id} (delete document)
resource "aws_api_gateway_integration" "delete_document_method_delete_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.delete_document_id_resource.id
  http_method = aws_api_gateway_method.delete_document_method_delete.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.delete_document_lambda.invoke_arn
}

# Lambda permissions for DELETE method (delete document)
resource "aws_lambda_permission" "delete_document_method_delete_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_document_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
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
    "method.response.header.Access-Control-Allow-Origin"       = "'*'"
    "method.response.header.Access-Control-Allow-Methods"      = "'GET,POST,OPTIONS,DELETE'"
    "method.response.header.Access-Control-Allow-Headers"      = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials"  = "'true'"
  }
}

# Options method for CORS support (POST /upload)
resource "aws_api_gateway_method" "upload_method_options" {
  rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id   = aws_api_gateway_resource.upload_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "upload_method_options_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.upload_resource.id
  http_method = aws_api_gateway_method.upload_method_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"       = true
    "method.response.header.Access-Control-Allow-Methods"      = true
    "method.response.header.Access-Control-Allow-Headers"      = true
    "method.response.header.Access-Control-Allow-Credentials"  = true
  }
}

resource "aws_api_gateway_integration" "upload_options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id             = aws_api_gateway_resource.upload_resource.id
  http_method             = aws_api_gateway_method.upload_method_options.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "upload_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
  resource_id = aws_api_gateway_resource.upload_resource.id
  http_method = aws_api_gateway_method.upload_method_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"       = "'*'"
    "method.response.header.Access-Control-Allow-Methods"      = "'GET,POST,OPTIONS,DELETE'"
    "method.response.header.Access-Control-Allow-Headers"      = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials"  = "'true'"
  }
}

