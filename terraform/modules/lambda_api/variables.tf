variable "function_name" {
  description = "Lambda function name for the API backend."
  type        = string
}

variable "bedrock_model" {
  description = "Bedrock model identifier for LLM reasoning."
  type        = string
}

variable "sagemaker_endpoint_name" {
  description = "SageMaker endpoint invoked for fraud scoring."
  type        = string
}

variable "opensearch_collection_arn" {
  description = "OpenSearch Serverless collection ARN for vector lookups."
  type        = string
}

variable "opensearch_index_name" {
  description = "OpenSearch index used for vector retrieval."
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for claim and policy data access."
  type        = string
}

variable "dynamodb_table_arn" {
  description = "DynamoDB table ARN for governance logging."
  type        = string
}
