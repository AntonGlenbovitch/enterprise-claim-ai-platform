data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "claims_api" {
  name        = var.api_name
  description = "API for AI-powered insurance claim analysis."
}

resource "aws_api_gateway_resource" "claims" {
  rest_api_id = aws_api_gateway_rest_api.claims_api.id
  parent_id   = aws_api_gateway_rest_api.claims_api.root_resource_id
  path_part   = "claims"
}

resource "aws_api_gateway_resource" "analyze" {
  rest_api_id = aws_api_gateway_rest_api.claims_api.id
  parent_id   = aws_api_gateway_resource.claims.id
  path_part   = "analyze"
}

resource "aws_api_gateway_method" "post_analyze" {
  rest_api_id   = aws_api_gateway_rest_api.claims_api.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_analyze_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.claims_api.id
  resource_id             = aws_api_gateway_resource.analyze.id
  http_method             = aws_api_gateway_method.post_analyze.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = 14
}

resource "aws_iam_role" "apigw_cloudwatch_role" {
  name = "${var.api_name}-apigw-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch_policy" {
  role       = aws_iam_role.apigw_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
}

resource "aws_api_gateway_deployment" "claims_api" {
  rest_api_id = aws_api_gateway_rest_api.claims_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.claims.id,
      aws_api_gateway_resource.analyze.id,
      aws_api_gateway_method.post_analyze.id,
      aws_api_gateway_integration.post_analyze_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.claims_api.id
  deployment_id = aws_api_gateway_deployment.claims_api.id
  stage_name    = "prod"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.claims_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.claims_api.id}/*/${aws_api_gateway_method.post_analyze.http_method}${aws_api_gateway_resource.analyze.path}"
}
