"""Validation helpers for model responses in claim adjudication workflows."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Iterable, Mapping


@dataclass(frozen=True)
class ValidationResult:
    """Structured output for response validation checks."""

    is_valid: bool
    errors: list[str] = field(default_factory=list)
    missing_fields: list[str] = field(default_factory=list)
    unsupported_claims: list[str] = field(default_factory=list)
    policy_mismatch: bool = False



def _normalize_claims(raw_claims: Any) -> list[str]:
    """Normalize a response claim payload into a list of claim strings."""

    if raw_claims is None:
        return []
    if isinstance(raw_claims, str):
        return [raw_claims]
    if isinstance(raw_claims, Iterable):
        claims: list[str] = []
        for claim in raw_claims:
            if isinstance(claim, str):
                claims.append(claim)
        return claims
    return []



def validate_response(
    response: Mapping[str, Any],
    *,
    required_fields: Iterable[str],
    expected_policy_id: str | None = None,
    supported_claims: Iterable[str] | None = None,
    policy_field: str = "policy_id",
    claims_field: str = "supported_claims",
) -> ValidationResult:
    """Validate a model response for required fields and policy/claim consistency.

    Args:
        response: Response payload returned by an LLM or service.
        required_fields: Keys that must exist and hold non-empty values.
        expected_policy_id: Canonical policy identifier expected for this workflow.
        supported_claims: Allowlist of claims that the response may reference.
        policy_field: Key used for the policy identifier in ``response``.
        claims_field: Key used for response claims in ``response``.

    Returns:
        A :class:`ValidationResult` containing all detected issues.
    """

    missing_fields = [
        field_name
        for field_name in required_fields
        if field_name not in response or response[field_name] in (None, "", [], {})
    ]

    policy_mismatch = False
    if expected_policy_id is not None:
        actual_policy_id = str(response.get(policy_field, "")).strip()
        policy_mismatch = actual_policy_id != expected_policy_id

    unsupported: list[str] = []
    if supported_claims is not None:
        allowed_claims = {claim for claim in supported_claims if isinstance(claim, str)}
        response_claims = _normalize_claims(response.get(claims_field))
        unsupported = sorted({claim for claim in response_claims if claim not in allowed_claims})

    errors: list[str] = []
    if missing_fields:
        errors.append(f"Missing required fields: {', '.join(missing_fields)}")
    if policy_mismatch:
        errors.append(
            f"Policy mismatch: expected '{expected_policy_id}' but got "
            f"'{str(response.get(policy_field, '')).strip()}'"
        )
    if unsupported:
        errors.append(f"Unsupported claims: {', '.join(unsupported)}")

    return ValidationResult(
        is_valid=not errors,
        errors=errors,
        missing_fields=missing_fields,
        unsupported_claims=unsupported,
        policy_mismatch=policy_mismatch,
    )
