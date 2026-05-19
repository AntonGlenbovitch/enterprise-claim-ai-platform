output "endpoint_name" {
  description = "Name of the fraud model endpoint."
  value       = aws_sagemaker_endpoint.fraud_model_endpoint.name
}

output "endpoint_arn" {
  description = "ARN of the SageMaker endpoint."
  value       = aws_sagemaker_endpoint.fraud_model_endpoint.arn
}
