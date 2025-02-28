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
    depends_on = [ aws_api_gateway_method.test_method, aws_api_gateway_integration.get_users_integration ]
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

resource "aws_api_gateway_method" "documents_method_options" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.documents_resource.id
    http_method   = "OPTIONS"
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

resource "aws_api_gateway_method" "upload_method_options" {
    rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
    resource_id   = aws_api_gateway_resource.upload_resource.id
    http_method   = "OPTIONS"
    authorization = "AWS_IAM"
}

# TODO - add lambda function integration
# resource "aws_api_gateway_integration" "documents_integration" {
#     rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
#     resource_id = aws_api_gateway_resource.documents_resource.id
#     http_method = aws_api_gateway_method.test_method.http_method
    
#     integration_http_method = "GET"
#     type                    = "MOCK"  # Or "AWS", "HTTP" depending on your use case
    
#     # Optional: Set the request/response templates
#     request_templates = {
#         "application/json" = jsonencode({ "statusCode": 200 })
#     }
# }

# create a GET method for the /test resource
# resource "aws_api_gateway_method" "test_method" {
#     rest_api_id   = aws_api_gateway_rest_api.lsm-fyp-api.id
#     resource_id   = aws_api_gateway_resource.test_resource.id
#     http_method   = "GET"
#     authorization = "AWS_IAM"
# }

# Create an integration for the GET method (e.g., Mock Integration)
# resource "aws_api_gateway_integration" "get_users_integration" {
#   rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
#   resource_id = aws_api_gateway_resource.test_resource.id
#   http_method = aws_api_gateway_method.test_method.http_method

#   integration_http_method = "GET"
#   type                    = "MOCK"  # Or "AWS", "HTTP" depending on your use case

#   # Optional: Set the request/response templates
#   request_templates = {
#     "application/json" = jsonencode({ "statusCode": 200 })
#   }
# }