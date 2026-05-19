resource "aws_iam_role" "step_functions_role" {
  name = "${var.state_machine_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${var.state_machine_name}-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.lambda_function_arn,
          "${var.lambda_function_arn}:*"
        ]
      }
    ]
  })
}

locals {
  state_machine_definition = {
    Comment = "Insurance AI claim analysis workflow"
    StartAt = "retrieve_claim"
    States = {
      retrieve_claim = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_function_arn
          Payload = {
            task = "retrieve_claim"
            input.$ = "$.detail"
          }
        }
        ResultPath = "$.retrieve_claim"
        Next       = "retrieve_policy"
      }
      retrieve_policy = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_function_arn
          Payload = {
            task     = "retrieve_policy"
            claim.$  = "$.retrieve_claim.Payload"
          }
        }
        ResultPath = "$.retrieve_policy"
        Next       = "run_fraud_model"
      }
      run_fraud_model = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_function_arn
          Payload = {
            task       = "run_fraud_model"
            claim.$    = "$.retrieve_claim.Payload"
            policy.$   = "$.retrieve_policy.Payload"
          }
        }
        ResultPath = "$.run_fraud_model"
        Next       = "llm_reasoning"
      }
      llm_reasoning = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_function_arn
          Payload = {
            task         = "llm_reasoning"
            claim.$      = "$.retrieve_claim.Payload"
            policy.$     = "$.retrieve_policy.Payload"
            fraud.$      = "$.run_fraud_model.Payload"
          }
        }
        ResultPath = "$.llm_reasoning"
        Next       = "store_result"
      }
      store_result = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_function_arn
          Payload = {
            task      = "store_result"
            analysis.$ = "$.llm_reasoning.Payload"
          }
        }
        End = true
      }
    }
  }
}

resource "aws_sfn_state_machine" "claim_analysis" {
  name     = var.state_machine_name
  role_arn = aws_iam_role.step_functions_role.arn
  definition = jsonencode(local.state_machine_definition)
}
