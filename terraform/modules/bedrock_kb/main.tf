data "aws_iam_policy_document" "bedrock_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "bedrock_kb_role" {
  name               = "${var.knowledge_base_name}-role"
  assume_role_policy = data.aws_iam_policy_document.bedrock_assume_role.json
}

data "aws_iam_policy_document" "bedrock_kb_permissions" {
  statement {
    sid    = "AllowS3PolicyDocRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/${var.s3_policy_docs_prefix}*"
    ]
  }

  statement {
    sid    = "AllowOpenSearchVectorAccess"
    effect = "Allow"
    actions = [
      "aoss:APIAccessAll"
    ]
    resources = [
      var.opensearch_collection_arn
    ]
  }

  statement {
    sid    = "AllowTitanEmbeddingInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel"
    ]
    resources = [
      var.embedding_model_arn
    ]
  }
}

resource "aws_iam_role_policy" "bedrock_kb_permissions" {
  name   = "${var.knowledge_base_name}-permissions"
  role   = aws_iam_role.bedrock_kb_role.id
  policy = data.aws_iam_policy_document.bedrock_kb_permissions.json
}

resource "aws_bedrockagent_knowledge_base" "policy_kb" {
  name     = var.knowledge_base_name
  role_arn = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = var.embedding_model_arn
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"

    opensearch_serverless_configuration {
      collection_arn    = var.opensearch_collection_arn
      vector_index_name = var.vector_index_name

      field_mapping {
        vector_field   = "vector"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "policy_docs" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.policy_kb.id
  name              = "policy-docs-s3"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn = var.s3_bucket_arn

      inclusion_prefixes = [
        var.s3_policy_docs_prefix
      ]
    }
  }
}
