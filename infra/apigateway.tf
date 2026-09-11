resource "aws_api_gateway_rest_api" "api" {
    name = "datalens-api"
}

resource "aws_api_gateway_resource" "stats_resource" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "stats"
}

resource "aws_api_gateway_resource" "largest_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id = aws_api_gateway_rest_api.api.root_resource_id
  path_part = "largest"
}

resource "aws_api_gateway_resource" "recent_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id = aws_api_gateway_rest_api.api.root_resource_id
  path_part = "recent"
}

resource "aws_api_gateway_method" "stats_get" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.stats_resource.id
    http_method = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_method" "largest_get" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.largest_resource.id
    http_method = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_method" "recent_get" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.recent_resource.id
    http_method = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "stats_integration" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.stats_resource.id
    http_method = "GET"
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = aws_lambda_function.query.invoke_arn
}

resource "aws_api_gateway_integration" "largest_integration" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.largest_resource.id
    http_method = "GET"
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = aws_lambda_function.query.invoke_arn
}

resource "aws_api_gateway_integration" "recent_integration" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.recent_resource.id
    http_method = "GET"
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = aws_lambda_function.query.invoke_arn
}

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query.function_name

  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on = [ 
        aws_api_gateway_integration.stats_integration,
        aws_api_gateway_integration.largest_integration,
        aws_api_gateway_integration.recent_integration
   ]
}

resource "aws_api_gateway_stage" "prod" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    stage_name = "prod"
    deployment_id = aws_api_gateway_deployment.deployment.id
}