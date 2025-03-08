resource "aws_api_gateway_rest_api" "lsm_fyp_api" {
  name        = "lsm-fyp-api"
  description = "API Gateway for LSM FYP Project"
}

resource "aws_api_gateway_resource" "delete_document" {
  rest_api_id = aws_api_gateway_rest_api.lsm_fyp_api.id
  parent_id   = aws_api_gateway_rest_api.lsm_fyp_api.root_resource_id
  path_part   = "documents"  # This is the endpoint part
}

resource "aws_api_gateway_method" "delete_document_method" {
  rest_api_id   = aws_api_gateway_rest_api.lsm_fyp_api.id
  resource_id   = aws_api_gateway_resource.delete_document.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "delete_document_method_integration" {
  rest_api_id = aws_api_gateway_rest_api.lsm_fyp_api.id
  resource_id = aws_api_gateway_resource.delete_document.id
  http_method = aws_api_gateway_method.delete_document_method.http_method
  type         = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = "arn:aws:apigateway:ap-southeast-1:lambda:path/2015-03-31/functions/${aws_lambda_function.delete_document_lambda_new.arn}/invocations"
}

resource "aws_api_gateway_method_response" "delete_document_method_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm_fyp_api.id
  resource_id = aws_api_gateway_resource.delete_document.id
  http_method = aws_api_gateway_method.delete_document_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "delete_document_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lsm_fyp_api.id
  resource_id = aws_api_gateway_resource.delete_document.id
  http_method = aws_api_gateway_method.delete_document_method.http_method
  status_code = "200"
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lsm_fyp_api.id
  stage_name  = "prod"  # You can also create a stage for test or dev
}

resource "aws_api_gateway_stage" "prod_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.lsm_fyp_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_document_lambda_new.function_name
  principal     = "apigateway.amazonaws.com"
}
