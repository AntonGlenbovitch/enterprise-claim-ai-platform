output "state_machine_arn" {
  description = "ARN of the claim analysis Step Functions state machine."
  value       = aws_sfn_state_machine.claim_analysis.arn
}

output "state_machine_name" {
  description = "Name of the claim analysis Step Functions state machine."
  value       = aws_sfn_state_machine.claim_analysis.name
}
