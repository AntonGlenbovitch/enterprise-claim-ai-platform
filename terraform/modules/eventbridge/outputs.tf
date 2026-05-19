output "event_bus_arn" {
  description = "ARN of the claim analysis event bus."
  value       = aws_cloudwatch_event_bus.claim_analysis.arn
}

output "rule_arn" {
  description = "ARN of the claim analysis event rule."
  value       = aws_cloudwatch_event_rule.claim_analysis_requested.arn
}
