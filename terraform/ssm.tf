resource "aws_ssm_parameter" "db_credentials" {
    name = "${var.project_name}-rds-credentials"
    type = "SecureString"
    value = jsonencode({ # in production, this should be stored in tfvars or AWA Secrets Manager
        username = "admin"
        password = "PleaseGiveUsA+"
    })
}

data "aws_ssm_parameter" "db_credentials" {
    name = aws_ssm_parameter.db_credentials.name
}