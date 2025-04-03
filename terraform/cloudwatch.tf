// cloudwatch groups for lambda functions
resource "aws_cloudwatch_log_group" "delete_document_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.delete_document_lambda.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "fetch_documents_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_documents_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "fetch_corrected_documents_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_corrected_documents_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "fetch_upload_url_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_upload_url_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "fetch_download_url_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_download_url_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "insert_rds_new_document_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.insert_rds_new_document_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "s3_trigger_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.s3_trigger_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "send_feedback_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.send_feedback_lambda.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "document_classification_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.document_classification_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "add_new_topic_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.add_new_topic_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "remove_topic_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.remove_topic_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "feedback_retraining_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.feedback_retraining_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "fetch_topics_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_topics_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "auth_lambda_edge_logs" {
  provider          = aws.us-east-1
  name              = "/aws/lambda/${aws_lambda_function.rds_init_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}

resource "aws_cloudwatch_log_group" "rds_init_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.rds_init_lambda.function_name}"
  retention_in_days = 7 # Adjust retention as needed
}
