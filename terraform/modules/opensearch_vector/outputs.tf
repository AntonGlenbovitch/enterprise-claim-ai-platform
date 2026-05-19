output "collection_arn" {
  description = "ARN of the OpenSearch Serverless collection."
  value       = aws_opensearchserverless_collection.vector.arn
}

output "collection_endpoint" {
  description = "Collection endpoint used by Bedrock knowledge base and ingestion pipelines."
  value       = aws_opensearchserverless_collection.vector.collection_endpoint
}

output "vector_index_name" {
  description = "Vector index name for policy embeddings."
  value       = var.vector_index_name
}

output "vector_index_definition" {
  description = "Reference OpenSearch index mapping for the policy vector index."
  value       = local.vector_index_definition
}
