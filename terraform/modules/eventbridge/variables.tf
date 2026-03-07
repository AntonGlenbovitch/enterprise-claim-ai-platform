variable "event_bus_name" {
  description = "Custom EventBridge bus name for claim analysis events."
  type        = string
}

variable "rule_name" {
  description = "EventBridge rule name for claim analysis requests."
  type        = string
}

variable "state_machine_arn" {
  description = "Step Functions state machine ARN target."
  type        = string
}

variable "state_machine_name" {
  description = "Step Functions state machine name."
  type        = string
}
