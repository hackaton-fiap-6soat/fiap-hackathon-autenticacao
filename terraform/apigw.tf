
resource "aws_apigatewayv2_api" "api" {
  name          = "api_gw_api"
  protocol_type = "HTTP"
}


resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}
