variable "state_machine_name" {
  description = "Name of the claim analysis state machine."
  type        = string
}

variable "lambda_function_arn" {
  description = "Lambda ARN used for each workflow task."
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name used in IAM policy scoping."
  type        = string
}
