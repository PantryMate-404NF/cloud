output "webhook_url" {
  description = "GitHub 웹훅 설정에 등록할 공개 API Gateway URL. 경로 /webhook 포함."
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/webhook"
}

output "lambda_function_name" {
  description = "webhook relay Lambda 함수 이름."
  value       = aws_lambda_function.webhook_relay.function_name
}

output "api_gateway_id" {
  description = "API Gateway HTTP API ID."
  value       = aws_apigatewayv2_api.webhook.id
}
