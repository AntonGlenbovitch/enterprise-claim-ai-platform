output "table_name" {
  description = "Name of the audit table."
  value       = aws_dynamodb_table.audit.name
}

output "table_arn" {
  description = "ARN of the audit table."
  value       = aws_dynamodb_table.audit.arn
}
