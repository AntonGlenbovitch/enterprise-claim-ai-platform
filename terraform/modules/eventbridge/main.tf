resource "aws_cloudwatch_event_bus" "claim_analysis" {
  name = var.event_bus_name
}

resource "aws_cloudwatch_event_rule" "claim_analysis_requested" {
  name           = var.rule_name
  event_bus_name = aws_cloudwatch_event_bus.claim_analysis.name
  description    = "Routes claim analysis requests to Step Functions workflow."

  event_pattern = jsonencode({
    source      = ["enterprise.claims"]
    detail-type = ["ClaimAnalysisRequested"]
  })
}

resource "aws_iam_role" "eventbridge_target_role" {
  name = "${var.rule_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_target_policy" {
  name = "${var.rule_name}-eventbridge-policy"
  role = aws_iam_role.eventbridge_target_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = var.state_machine_arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "step_functions_target" {
  rule           = aws_cloudwatch_event_rule.claim_analysis_requested.name
  event_bus_name = aws_cloudwatch_event_bus.claim_analysis.name
  arn            = var.state_machine_arn
  role_arn       = aws_iam_role.eventbridge_target_role.arn
}
