output "api_gateway_url" {
  description = "Invoke URL for the REST API stage."
  value       = module.api_gateway.invoke_url
}

output "s3_bucket_name" {
  description = "Name of the S3 data lake bucket."
  value       = module.s3_datalake.bucket_name
}

output "sagemaker_endpoint_name" {
  description = "SageMaker endpoint that serves the fraud model."
  value       = module.sagemaker_endpoint.endpoint_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table used for governance and audit logs."
  value       = module.dynamodb_audit.table_name
}
