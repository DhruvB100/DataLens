resource "aws_sns_topic" "alerts" {
  name = "datalens-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol = "email"
  endpoint = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "ingest_errors" {
  alarm_name = "datalens-ingest-errors"
  alarm_description = "Fires when the ingest Lambda throws any errors"
  comparison_operator = "GreaterThanThreshold"
  threshold = 0
  evaluation_periods = 1
  period = 300

  statistic = "Sum"
  metric_name = "Errors"
  namespace = "AWS/Lambda"
  dimensions = {FunctionName = aws_lambda_function.ingest.function_name}
  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "datalens"
  dashboard_body = jsonencode({
    widgets = [
        {
            type = "metric"
            x= 0
            y = 0
            width = 12
            height = 6

            properties = {
                title = "Lambda Invocations"
                view = "timeSeries"
                region = "us-east-1"
                period = 300
                stat = "Sum"
                metrics = [
                    ["AWS/Lambda","Invocations","FunctionName",aws_lambda_function.ingest.function_name],
                    ["AWS/Lambda","Invocations","FunctionName",aws_lambda_function.transform.function_name],
                    ["AWS/Lambda","Invocations","FunctionName",aws_lambda_function.query.function_name],
                    ["AWS/Lambda","Invocations","FunctionName",aws_lambda_function.ai_query.function_name]
                ]
            }
        },
        {
            type = "metric"
            x= 0
            y = 6
            width = 12
            height = 6

            properties = {
                title = "Lambda Errors"
                view = "timeSeries"
                region = "us-east-1"
                period = 300
                stat = "Sum"
                metrics = [
                    ["AWS/Lambda","Errors","FunctionName",aws_lambda_function.ingest.function_name],
                    ["AWS/Lambda","Errors","FunctionName",aws_lambda_function.transform.function_name],
                    ["AWS/Lambda","Errors","FunctionName",aws_lambda_function.query.function_name],
                    ["AWS/Lambda","Errors","FunctionName",aws_lambda_function.ai_query.function_name]
                ]
            }
        }

    ]
  })
}