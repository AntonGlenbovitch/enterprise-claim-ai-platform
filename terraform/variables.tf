variable "aws_region" {
  description = "AWS region for all platform resources."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags applied to all resources for governance and cost management."
  type        = map(string)
  default = {
    Project     = "enterprise-claim-ai-platform"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}

variable "bedrock_model" {
  description = "Foundation model used by the claim analysis API."
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "titan_embedding_model_arn" {
  description = "ARN for the Bedrock Titan embedding model used by the knowledge base."
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
}

variable "opensearch_collection_type" {
  description = "OpenSearch Serverless collection type for vector workloads."
  type        = string
  default     = "VECTORSEARCH"
}
