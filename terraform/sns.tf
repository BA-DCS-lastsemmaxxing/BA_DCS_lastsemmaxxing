resource "aws_sqs_queue" "add_new_topic_queue" {
  name                       = "add-new-topic-queue"
  visibility_timeout_seconds = 910
}

resource "aws_lambda_event_source_mapping" "add_new_topic_queue_mapping" {
  event_source_arn = aws_sqs_queue.add_new_topic_queue.arn
  function_name    = aws_lambda_function.add_new_topic_lambda.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_sqs_queue" "remove_topic_queue" {
  name                       = "remove-topic-queue"
  visibility_timeout_seconds = 910
}

resource "aws_lambda_event_source_mapping" "remove_topic_queue_mapping" {
  event_source_arn = aws_sqs_queue.remove_topic_queue.arn
  function_name    = aws_lambda_function.remove_topic_lambda.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_sqs_queue" "feedback_retraining_queue" {
  name                       = "feedback-retraining-queue"
  visibility_timeout_seconds = 910
}

resource "aws_lambda_event_source_mapping" "feedback_retraining_queue_mapping" {
  event_source_arn = aws_sqs_queue.feedback_retraining_queue.arn
  function_name    = aws_lambda_function.feedback_retraining_lambda.arn
  batch_size       = 1
  enabled          = true
}
