output "rest_api_id" {
  description = "ID of the API Gateway REST API."
  value       = aws_api_gateway_rest_api.claims_api.id
}

output "invoke_url" {
  description = "Invoke URL for the prod stage."
  value       = aws_api_gateway_stage.prod.invoke_url
}
