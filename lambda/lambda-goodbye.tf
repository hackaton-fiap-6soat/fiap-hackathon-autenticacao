
# Package the Lambda function
data "archive_file" "goodbye_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/goodbye"
  output_path = "${path.module}/goodbye.py.zip"
}

resource "aws_lambda_function" "goodbye_lambda" {
  filename         = "${path.module}/goodbye.py.zip"
  function_name    = "goodbye_lambda"
  role             = data.aws_iam_role.LabRole.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.goodbye_lambda_zip.output_base64sha256
  timeout          = 10

  depends_on = [ data.archive_file.goodbye_lambda_zip ]
}

# Api Gateway Integration
resource "aws_apigatewayv2_integration" "goodbye_lambda_integration" {
  api_id             = data.aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.goodbye_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "goodbye_lambda_api_route" {
  api_id    = data.aws_apigatewayv2_api.api.id
  route_key = "GET /goodbye"
  target    = "integrations/${aws_apigatewayv2_integration.goodbye_lambda_integration.id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_lambda_permission" "goodbye_lambda_allow_apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.goodbye_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_apigatewayv2_api.api.execution_arn}/*"
}

output "goodbye_endpoint" {
  value = "${data.aws_apigatewayv2_api.api.api_endpoint}/goodbye"
}