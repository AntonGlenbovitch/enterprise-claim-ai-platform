"""Service helpers for fraud scoring using an Amazon SageMaker endpoint."""

from __future__ import annotations

import json
import os
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError

_ENDPOINT_NAME_ENV = "FRAUD_SAGEMAKER_ENDPOINT"
_CONTENT_TYPE = "application/json"

_runtime_client = boto3.client("sagemaker-runtime")


class FraudPredictionError(RuntimeError):
    """Raised when the fraud prediction endpoint call fails."""


def _extract_probability(result: Any) -> float:
    """Extract a fraud probability value from a SageMaker endpoint response payload."""

    if isinstance(result, (int, float)):
        return float(result)

    if isinstance(result, list) and result:
        first_item = result[0]
        if isinstance(first_item, (int, float)):
            return float(first_item)
        if isinstance(first_item, dict):
            for key in ("fraud_probability", "probability", "score"):
                if key in first_item:
                    return float(first_item[key])

    if isinstance(result, dict):
        for key in ("fraud_probability", "probability", "score"):
            if key in result:
                return float(result[key])

    raise FraudPredictionError("SageMaker response did not contain a fraud probability")


def predict_fraud_risk(claim_payload: dict[str, Any]) -> float:
    """Invoke SageMaker and return a fraud probability for the claim payload."""

    endpoint_name = os.getenv(_ENDPOINT_NAME_ENV)
    if not endpoint_name:
        raise FraudPredictionError(f"Environment variable {_ENDPOINT_NAME_ENV} is required")

    try:
        response = _runtime_client.invoke_endpoint(
            EndpointName=endpoint_name,
            ContentType=_CONTENT_TYPE,
            Body=json.dumps(claim_payload).encode("utf-8"),
        )
        raw_payload = response["Body"].read().decode("utf-8")
        parsed_payload = json.loads(raw_payload)
        return _extract_probability(parsed_payload)
    except (ClientError, BotoCoreError) as exc:
        raise FraudPredictionError(
            f"Failed to invoke SageMaker endpoint '{endpoint_name}'"
        ) from exc
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError, TypeError) as exc:
        raise FraudPredictionError("Invalid payload returned by SageMaker endpoint") from exc
