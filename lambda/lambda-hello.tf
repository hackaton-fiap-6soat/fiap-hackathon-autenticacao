
# Package the Lambda function
data "archive_file" "hello_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/hello"
  output_path = "${path.module}/hello.py.zip"
}

resource "aws_lambda_function" "hello_lambda" {
  filename         = "${path.module}/hello.py.zip"
  function_name    = "hello_lambda"
  role             = data.aws_iam_role.LabRole.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.hello_lambda_zip.output_base64sha256
  timeout          = 10

  depends_on = [ data.archive_file.hello_lambda_zip ]
}

# Api Gateway Integration
resource "aws_apigatewayv2_integration" "hello_lambda_integration" {
  api_id             = data.aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.hello_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "hello_lambda_api_route" {
  api_id    = data.aws_apigatewayv2_api.api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_lambda_integration.id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_lambda_permission" "hello_lambda_allow_apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_apigatewayv2_api.api.execution_arn}/*"
}

output "hello_endpoint" {
  value = "${data.aws_apigatewayv2_api.api.api_endpoint}/hello"
}