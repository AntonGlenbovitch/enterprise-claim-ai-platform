data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.collection_name}-encryption"
  type        = "encryption"
  description = "Encryption policy for policy vector collection."
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.collection_name}"]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${var.collection_name}-network"
  type        = "network"
  description = "Network policy allowing IAM-authenticated access to the collection."
  policy = jsonencode([
    {
      Description = "Allow public endpoint access with IAM auth controls"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${var.collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_collection" "vector" {
  name        = var.collection_name
  description = "Vector collection for policy document embeddings."
  type        = var.collection_type

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]
}

resource "aws_opensearchserverless_access_policy" "collection_access" {
  name        = "${var.collection_name}-access"
  type        = "data"
  description = "Least-privilege access policy for vector index operations."
  policy = jsonencode([
    {
      Description = "Allow platform IAM principals to manage vector collection and index"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.collection_name}"]
          Permission   = ["aoss:CreateCollectionItems", "aoss:UpdateCollectionItems", "aoss:DescribeCollectionItems"]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${var.collection_name}/${var.vector_index_name}"]
          Permission   = ["aoss:CreateIndex", "aoss:UpdateIndex", "aoss:DescribeIndex", "aoss:ReadDocument", "aoss:WriteDocument"]
        }
      ]
      Principal = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  ])
}

# Bedrock Knowledge Base uses this index name and creates mappings during ingestion.
locals {
  vector_index_definition = {
    settings = {
      index = {
        knn = true
      }
    }
    mappings = {
      properties = {
        vector = {
          type      = "knn_vector"
          dimension = var.vector_dimension
          method = {
            name       = "hnsw"
            engine     = "faiss"
            space_type = var.vector_similarity
          }
        }
        text = {
          type = "text"
        }
      }
    }
  }
}
