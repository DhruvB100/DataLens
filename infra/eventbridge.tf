resource "aws_cloudwatch_event_rule" "ingest_schedule" {
  name = "datalens-ingest-schedule"
  schedule_expression = "rate(6 hours)"
}

resource "aws_cloudwatch_event_target" "ingest_target" {
  rule = aws_cloudwatch_event_rule.ingest_schedule.name
  arn = aws_lambda_function.ingest.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id = "AllowEventBridgeInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name

  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.ingest_schedule.arn
}