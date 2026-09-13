# the one rest api that all four endpoints live under
resource "aws_api_gateway_rest_api" "api" {
    name = "datalens-api"
}

# one resource block per url path (stats/largest/recent/ask)
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

# GET methods, no auth - these are meant to be public
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

# lambda proxy integrations - integration_http_method is always POST here,
# that's just how api gateway talks to lambda regardless of the client's verb
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

# ask uses POST since it takes a question in the request body, not a GET
resource "aws_api_gateway_resource" "ask_resource" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "ask"
}

resource "aws_api_gateway_method" "ask_post" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.ask_resource.id
    http_method = "POST"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "ask_integration" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.ask_resource.id
    http_method = "POST"
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = aws_lambda_function.ai_query.invoke_arn
}

resource "aws_lambda_permission" "allow_apigw_invoke_ai_query" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.ai_query.function_name

    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# publishes the api - the triggers hash is what actually forces a new
# deployment when routes change, depends_on alone only controls order.
# learned this the hard way when /ask didn't show up after adding it.
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on = [
        aws_api_gateway_integration.stats_integration,
        aws_api_gateway_integration.largest_integration,
        aws_api_gateway_integration.recent_integration,
        aws_api_gateway_integration.ask_integration
   ]
   triggers = {
    "redeployment" = sha1(jsonencode([
        aws_api_gateway_resource.stats_resource.id,
        aws_api_gateway_method.stats_get.id,
        aws_api_gateway_integration.stats_integration.id,

        aws_api_gateway_resource.largest_resource.id,
        aws_api_gateway_method.largest_get.id,
        aws_api_gateway_integration.largest_integration.id,

        aws_api_gateway_resource.recent_resource.id,
        aws_api_gateway_method.recent_get.id,
        aws_api_gateway_integration.recent_integration.id,

        aws_api_gateway_resource.ask_resource.id,
        aws_api_gateway_method.ask_post.id,
        aws_api_gateway_integration.ask_integration.id
    ]))
   }
   lifecycle {
     create_before_destroy = true
   }
}

resource "aws_api_gateway_stage" "prod" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    stage_name = "prod"
    deployment_id = aws_api_gateway_deployment.deployment.id
}