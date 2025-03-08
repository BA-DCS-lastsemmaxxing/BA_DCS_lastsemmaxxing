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
    name = "${var.project_name}-authorizer"
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    type = "COGNITO_USER_POOLS"
    provider_arns = [aws_cognito_user_pool.lsm-fyp-user-pool.arn]
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

    # edit this for the methods/integrations for api gateway
    depends_on = [
        aws_api_gateway_method.documents_method_get,
        aws_api_gateway_method.documents_method_options,
        aws_api_gateway_method.upload_method_post,
        aws_api_gateway_method.upload_method_options
    ]
}

# use these to create endpoints
# create a resource for the API (e.g /users)

# create a method for /documents
resource "aws_api_gateway_resource" "documents_resource" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
    path_part   = "documents"
}

# GET for /documents
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
    
    integration_http_method = "POST" # Always POST for Lambda proxy integration
    type = "AWS_PROXY"
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

# Create /upload resource
resource "aws_api_gateway_resource" "upload_resource" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
    path_part   = "upload"
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
        "method.response.header.Access-Control-Allow-Origin" = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
        "method.response.header.Access-Control-Allow-Credentials" = "'true'"
    }
}

resource "aws_api_gateway_method" "upload_method_post" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.upload_resource.id
    http_method   = "POST"
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = aws_api_gateway_authorizer.lsm-fyp-authorizer.id
}

resource "aws_api_gateway_integration" "upload_method_post_integration" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.upload_resource.id
    http_method = aws_api_gateway_method.upload_method_post.http_method
    
    integration_http_method = "POST" # Always POST for Lambda proxy integration
    type = "AWS_PROXY"
    uri = aws_lambda_function.upload_document_lambda.invoke_arn
}

resource "aws_lambda_permission" "upload_method_post_lambda_permission" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.upload_document_lambda.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*/*"
}

// all options methods are for CORS support - test without since same CF origin
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
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
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
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
    }
}

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
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Credentials" = true
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
        "method.response.header.Access-Control-Allow-Origin" = "'*'"
        "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
        "method.response.header.Access-Control-Allow-Credentials" = "'true'"
    }
}


