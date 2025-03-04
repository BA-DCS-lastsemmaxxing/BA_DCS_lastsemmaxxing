resource "aws_cognito_user_pool" "lsm-fyp-user-pool" {
    name = "${var.project_name}-user-pool"

    auto_verified_attributes = ["email"]

    schema {
        name = "email"
        attribute_data_type = "String"
        required = true
        mutable = false # email cannot be changed after user registered
    }
}

resource "aws_cognito_gateway+authorizer" "lsm-fyp-authorizer" {
    name = "${var.project_name}-authorizer"
    rest_api_id = aws_api_gateway_rest_api.lsm-fyp-api.id
    type = "COGNITO_USER_POOLS"
    provider_arns = [aws_cognito_user_pool.lsm-fyp-user-pool.arn]
}

resource "aws_cognito_user_pool_client" "lsm-fyp-app-client" {
    name = "${var.project_name}-user-pool-client"
    user_pool_id = aws_cognito_user_pool.lsm-fyp-user-pool.id

    explicit_auth_flows = [
        // "ALLOW_ADMIN_USER_PASSWORD_AUTH", // Admin can set password for user
        "ALLOW_REFRESH_TOKEN_AUTH", // Allow refresh token
        "ALLOW_USER_SRP_AUTH"
    ]

    generate_secret = false
}