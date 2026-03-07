"""End-to-end AI workflow for insurance claim analysis.

Pipeline:
1. get_claim_data
2. retrieve_policy_context
3. predict_fraud_risk
4. build prompt
5. route model
6. call LLM
7. validate response
8. log governance data
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from audit_logger import AuditLogger, AuditLogEntry
from llm_router import select_model
from prompt_builder import build_claim_prompt
from response_validator import ValidationResult, validate_response

from backend.services.claim_service import get_claim_data
from backend.services.fraud_service import predict_fraud_risk
from backend.services.llm_service import generate_response
from backend.services.rag_service import retrieve_policy_context


@dataclass(slots=True)
class WorkflowResult:
    """Container for AI workflow outputs."""

    claim_data: dict[str, Any]
    policy_context: list[dict[str, Any]]
    fraud_risk: float
    prompt: str
    model_used: str
    llm_response: str
    validation: ValidationResult
    audit_entry: AuditLogEntry


def _policy_rules_from_context(policy_context: list[dict[str, Any]]) -> list[str]:
    """Extract textual policy rules from retrieved policy documents."""

    rules: list[str] = []
    for document in policy_context:
        section = str(document.get("section", "")).strip()
        title = str(document.get("title", "")).strip()
        content = str(document.get("content", "")).strip()
        policy_id = str(document.get("policy_id", "")).strip()

        parts = [part for part in [policy_id, title, section, content] if part]
        if parts:
            rules.append(" | ".join(parts))

    return rules or ["No policy context retrieved."]


def _route_task_type(fraud_risk: float) -> str:
    """Map risk bands to task type labels used by the model router."""

    if fraud_risk >= 0.7:
        return "reasoning"
    if fraud_risk >= 0.4:
        return "analysis"
    return "classification"


def run_claim_ai_workflow(
    claim_id: str,
    *,
    query_vector: list[float] | None = None,
    top_k: int = 5,
    audit_logger: AuditLogger | None = None,
) -> WorkflowResult:
    """Execute the full claim AI workflow from data retrieval to governance logging."""

    # 1) get_claim_data
    claim_data = get_claim_data(claim_id)

    # 2) retrieve_policy_context
    policy_context = retrieve_policy_context(query_vector=query_vector, top_k=top_k)

    # 3) predict_fraud_risk
    fraud_risk = predict_fraud_risk(claim_data)

    # 4) build prompt
    prompt = build_claim_prompt(
        claim_data=claim_data,
        fraud_score=fraud_risk,
        policy_rules=_policy_rules_from_context(policy_context),
    )

    # 5) route model
    task_type = _route_task_type(fraud_risk)
    model_used = select_model(task_type)

    # 6) call LLM
    llm_response = generate_response(prompt)

    # 7) validate response
    validation_payload = {
        "decision": llm_response,
        "policy_id": str(claim_data.get("policy_id", "")).strip(),
    }
    validation = validate_response(
        validation_payload,
        required_fields=("decision",),
        expected_policy_id=str(claim_data.get("policy_id", "")).strip() or None,
        supported_claims=None,
    )

    # 8) log governance data
    logger = audit_logger or AuditLogger()
    audit_entry = logger.log(
        claim_id=claim_id,
        model_used=model_used,
        retrieved_docs=policy_context,
        prompt=prompt,
        response=llm_response,
    )

    return WorkflowResult(
        claim_data=claim_data,
        policy_context=policy_context,
        fraud_risk=fraud_risk,
        prompt=prompt,
        model_used=model_used,
        llm_response=llm_response,
        validation=validation,
        audit_entry=audit_entry,
    )


__all__ = ["WorkflowResult", "run_claim_ai_workflow"]
