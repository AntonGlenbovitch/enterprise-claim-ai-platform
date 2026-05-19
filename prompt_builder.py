"""Utility helpers for composing claim-analysis prompts for LLMs."""

from __future__ import annotations

import json
from typing import Any


def build_claim_prompt(
    claim_data: dict[str, Any],
    fraud_score: float,
    policy_rules: str | list[str],
) -> str:
    """Build a structured prompt for claim review and fraud analysis.

    Args:
        claim_data: Claim attributes (claimant details, loss details, etc.).
        fraud_score: Model-generated risk score on a 0.0-1.0 scale.
        policy_rules: Policy text or a list of policy-rule strings.

    Returns:
        A complete prompt string ready to send to an LLM.

    Raises:
        ValueError: If required inputs are missing or malformed.
    """

    if not isinstance(claim_data, dict) or not claim_data:
        raise ValueError("claim_data must be a non-empty dictionary")

    if not isinstance(fraud_score, (int, float)):
        raise ValueError("fraud_score must be numeric")

    score = float(fraud_score)
    if not 0.0 <= score <= 1.0:
        raise ValueError("fraud_score must be between 0.0 and 1.0")

    if isinstance(policy_rules, list):
        cleaned_rules = [str(rule).strip() for rule in policy_rules if str(rule).strip()]
        if not cleaned_rules:
            raise ValueError("policy_rules list must contain at least one non-empty rule")
        policy_rules_text = "\n".join(f"- {rule}" for rule in cleaned_rules)
    else:
        policy_rules_text = str(policy_rules).strip()
        if not policy_rules_text:
            raise ValueError("policy_rules must be a non-empty string or list of strings")

    claim_json = json.dumps(claim_data, indent=2, sort_keys=True, default=str)

    return f"""You are an insurance claims analyst.

Review the claim, evaluate fraud risk, and determine policy compliance.
Return your response in this exact structure:
1. Decision: Approve, Deny, or Escalate
2. Confidence: High, Medium, or Low
3. Rationale: Short explanation citing claim details and policy rules
4. Follow-up Actions: Bullet list of next steps

Claim Data:
{claim_json}

Fraud Score:
{score:.4f}

Policy Rules:
{policy_rules_text}
"""
