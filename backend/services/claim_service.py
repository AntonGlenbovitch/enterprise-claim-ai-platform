"""Service helpers for loading claim data from object storage."""

from __future__ import annotations

import json
import os
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError

_CLAIMS_BUCKET_ENV = "CLAIMS_S3_BUCKET"
_CLAIMS_PREFIX_ENV = "CLAIMS_S3_PREFIX"
_DEFAULT_CLAIMS_PREFIX = "claims"

_s3_client = boto3.client("s3")


class ClaimDataError(RuntimeError):
    """Raised when claim data cannot be loaded from S3."""


def _claim_key(claim_id: str) -> str:
    prefix = os.getenv(_CLAIMS_PREFIX_ENV, _DEFAULT_CLAIMS_PREFIX).strip("/")
    return f"{prefix}/{claim_id}.json"


def get_claim_data(claim_id: str) -> dict[str, Any]:
    """Load claim data for ``claim_id`` from S3.

    Claim JSON is expected at ``<prefix>/<claim_id>.json`` where ``prefix``
    defaults to ``claims`` and can be overridden with ``CLAIMS_S3_PREFIX``.
    The target bucket must be set in ``CLAIMS_S3_BUCKET``.
    """

    bucket = os.getenv(_CLAIMS_BUCKET_ENV)
    if not bucket:
        raise ClaimDataError(f"Environment variable {_CLAIMS_BUCKET_ENV} is required")

    key = _claim_key(claim_id)

    try:
        response = _s3_client.get_object(Bucket=bucket, Key=key)
        payload = response["Body"].read().decode("utf-8")
        return json.loads(payload)
    except (ClientError, BotoCoreError) as exc:
        raise ClaimDataError(f"Failed to load claim '{claim_id}' from s3://{bucket}/{key}") from exc
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ClaimDataError(
            f"Claim '{claim_id}' in s3://{bucket}/{key} did not contain valid JSON"
        ) from exc
