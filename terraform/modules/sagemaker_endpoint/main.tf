resource "aws_iam_role" "sagemaker_execution_role" {
  name = "${var.endpoint_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_basic_execution" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_sagemaker_model" "fraud_model" {
  name               = "${var.endpoint_name}-model"
  execution_role_arn = aws_iam_role.sagemaker_execution_role.arn

  primary_container {
    image = var.xgboost_image_uri

    environment = {
      SAGEMAKER_PROGRAM = "inference.py"
    }
  }
}

resource "aws_sagemaker_endpoint_configuration" "fraud_model_config" {
  name = "${var.endpoint_name}-config"

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.fraud_model.name
    initial_instance_count = var.endpoint_instance_count
    instance_type          = var.endpoint_instance_type
  }
}

resource "aws_sagemaker_endpoint" "fraud_model_endpoint" {
  name                 = var.endpoint_name
  endpoint_config_name = aws_sagemaker_endpoint_configuration.fraud_model_config.name
}
