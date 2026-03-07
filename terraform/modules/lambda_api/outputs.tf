output "lambda_function_arn" {
  description = "ARN of the claim analysis API Lambda function."
  value       = aws_lambda_function.api.arn
}

output "lambda_function_name" {
  description = "Name of the claim analysis API Lambda function."
  value       = aws_lambda_function.api.function_name
}
