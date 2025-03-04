resource "aws_api_gateway_rest_api" "lsm-fyp-api" {
  name        = "${var.project_name}-apigw"
  description = "API Gateway for ${var.project_name}"
}

resource "aws_api_gateway_stage" "prod" {
    stage_name    = "prod"
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    deployment_id = aws_api_gateway_deployment.prod_deployment.id
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

resource "aws_api_gateway_resource" "documents_resource" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
    path_part   = "documents"
}

resource "aws_api_gateway_method" "documents_method_get" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.documents_resource.id
    http_method   = "GET"
    authorization = "AWS_IAM"
}

resource "aws_api_gateway_resource" "upload_resource" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    parent_id   = aws_api_gateway_rest_api.lsm-fyp-api.root_resource_id
    path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_method_post" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.upload_resource.id
    http_method   = "POST"
    authorization = "AWS_IAM"
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
    http_method = aws_api_gateway_method.documents_method_get.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
    }
}

resource "aws_api_gateway_method" "upload_method_options" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.upload_resource.id
    http_method   = "OPTIONS"
    authorization = "AWS_IAM"
}

resource "aws_api_gateway_method_response" "upload_method_options_response" {
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id = aws_api_gateway_resource.upload_resource.id
    http_method = aws_api_gateway_method.upload_method_post.http_method
    status_code = "200"
    
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
    }
}