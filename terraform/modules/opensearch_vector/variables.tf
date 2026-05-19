variable "collection_name" {
  description = "OpenSearch Serverless collection name."
  type        = string
}

variable "collection_type" {
  description = "Collection type, typically VECTORSEARCH."
  type        = string
  default     = "VECTORSEARCH"
}

variable "vector_index_name" {
  description = "Name of the vector index for policy embeddings."
  type        = string
}

variable "vector_dimension" {
  description = "Embedding vector dimensionality."
  type        = number
}

variable "vector_similarity" {
  description = "Similarity metric used by the vector index."
  type        = string
}
