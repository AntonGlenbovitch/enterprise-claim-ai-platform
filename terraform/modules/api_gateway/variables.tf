variable "api_name" {
  description = "Name of the API Gateway REST API."
  type        = string
}

variable "lambda_function_arn" {
  description = "Lambda function ARN used as API integration target."
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name used for invoke permission."
  type        = string
}
