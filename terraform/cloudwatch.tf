locals {
  lambda_functions_cloudwatch = merge(
    aws_lambda_function.zip_lambdas,
    {
      "document_classification_lambda" = aws_lambda_function.document_classification_lambda,
      "add_new_topic_lambda" = aws_lambda_function.add_new_topic_lambda,
      "remove_topic_lambda" = aws_lambda_function.remove_topic_lambda,
      "feedback_retraining_lambda" = aws_lambda_function.feedback_retraining_lambda,
      "auth_lambda_edge" = aws_lambda_function.auth_lambda_edge,
      "rds_init_lambda" = aws_lambda_function.rds_init_lambda,
    }
  )
}

// cloudwatch groups for lambda functions
resource "aws_cloudwatch_log_group" "lambda_log_groups" {
  for_each = local.lambda_functions_cloudwatch

  name              = "/aws/lambda/${each.value.function_name}"
  retention_in_days = 7
}