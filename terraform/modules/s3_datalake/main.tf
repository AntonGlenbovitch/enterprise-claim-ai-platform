resource "aws_s3_bucket" "datalake" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Prefix placeholder objects establish folder-like structure for ingestion and governance.
resource "aws_s3_object" "claims_prefix" {
  bucket  = aws_s3_bucket.datalake.id
  key     = "claims/"
  content = ""
}

resource "aws_s3_object" "policy_docs_prefix" {
  bucket  = aws_s3_bucket.datalake.id
  key     = "policy_docs/"
  content = ""
}

resource "aws_s3_object" "logs_prefix" {
  bucket  = aws_s3_bucket.datalake.id
  key     = "logs/"
  content = ""
}
