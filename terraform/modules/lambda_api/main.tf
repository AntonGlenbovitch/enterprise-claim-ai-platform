data "aws_region" "current" {}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/claim-analysis-api.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = [
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*"
    ]
  }

  statement {
    sid    = "SageMakerInvoke"
    effect = "Allow"
    actions = [
      "sagemaker:InvokeEndpoint"
    ]
    resources = [
      "arn:aws:sagemaker:${data.aws_region.current.name}:*:endpoint/${var.sagemaker_endpoint_name}"
    ]
  }

  statement {
    sid    = "S3DataLakeReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "OpenSearchVectorAccess"
    effect = "Allow"
    actions = [
      "aoss:APIAccessAll"
    ]
    resources = [
      var.opensearch_collection_arn
    ]
  }

  statement {
    sid    = "DynamoDBGovernanceLogs"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:Query"
    ]
    resources = [
      var.dynamodb_table_arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${var.function_name}-permissions"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_lambda_function" "api" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "claim_routes.handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      BEDROCK_MODEL      = var.bedrock_model
      SAGEMAKER_ENDPOINT = var.sagemaker_endpoint_name
      OPENSEARCH_INDEX   = var.opensearch_index_name
    }
  }
}
