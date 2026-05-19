variable "knowledge_base_name" {
  description = "Name of the Bedrock Knowledge Base."
  type        = string
}

variable "embedding_model_arn" {
  description = "Bedrock embedding model ARN (Titan embeddings)."
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 data lake bucket ARN containing policy documents."
  type        = string
}

variable "s3_policy_docs_prefix" {
  description = "Prefix in S3 where policy documents are stored."
  type        = string
}

variable "opensearch_collection_arn" {
  description = "OpenSearch Serverless collection ARN."
  type        = string
}

variable "opensearch_collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint."
  type        = string
}

variable "vector_index_name" {
  description = "Vector index in OpenSearch Serverless."
  type        = string
}
