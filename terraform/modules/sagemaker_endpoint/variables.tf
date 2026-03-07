variable "endpoint_name" {
  description = "Name of the SageMaker endpoint."
  type        = string
}

variable "endpoint_instance_type" {
  description = "Instance type for real-time inference."
  type        = string
  default     = "ml.m5.large"
}

variable "endpoint_instance_count" {
  description = "Number of endpoint instances."
  type        = number
  default     = 1
}

variable "xgboost_image_uri" {
  description = "Container image URI for XGBoost inference."
  type        = string
  default     = "246618743249.dkr.ecr.us-east-1.amazonaws.com/sagemaker-xgboost:1.7-1"
}
