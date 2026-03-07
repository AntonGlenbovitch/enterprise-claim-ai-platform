output "knowledge_base_id" {
  description = "Bedrock knowledge base ID."
  value       = aws_bedrockagent_knowledge_base.policy_kb.id
}

output "knowledge_base_arn" {
  description = "Bedrock knowledge base ARN."
  value       = aws_bedrockagent_knowledge_base.policy_kb.arn
}

output "knowledge_base_role_arn" {
  description = "IAM role used by Bedrock knowledge base."
  value       = aws_iam_role.bedrock_kb_role.arn
}
