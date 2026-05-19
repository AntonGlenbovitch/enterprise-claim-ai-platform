"""Service helpers for generating responses with Amazon Bedrock Runtime."""

from __future__ import annotations

import json
import os

import boto3
from botocore.exceptions import BotoCoreError, ClientError

_MODEL_ID_ENV = "BEDROCK_MODEL_ID"
_AWS_REGION_ENV = "AWS_REGION"
_DEFAULT_REGION = "us-east-1"
_CONTENT_TYPE = "application/json"
_ACCEPT = "application/json"
_MAX_TOKENS = 512

_bedrock_runtime = boto3.client(
    "bedrock-runtime",
    region_name=os.getenv(_AWS_REGION_ENV, _DEFAULT_REGION),
)


class LLMServiceError(RuntimeError):
    """Raised when text generation through Bedrock Runtime fails."""


def generate_response(prompt: str) -> str:
    """Generate a model response for ``prompt`` using Bedrock Runtime.

    Environment variables:
        - ``BEDROCK_MODEL_ID``: The Bedrock foundation model ID to invoke.
        - ``AWS_REGION`` (optional): AWS region for the runtime client.
    """

    model_id = os.getenv(_MODEL_ID_ENV)
    if not model_id:
        raise LLMServiceError(f"Environment variable {_MODEL_ID_ENV} is required")

    cleaned_prompt = (prompt or "").strip()
    if not cleaned_prompt:
        raise LLMServiceError("Prompt must be a non-empty string")

    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": _MAX_TOKENS,
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": cleaned_prompt}],
            }
        ],
    }

    try:
        response = _bedrock_runtime.invoke_model(
            modelId=model_id,
            contentType=_CONTENT_TYPE,
            accept=_ACCEPT,
            body=json.dumps(request_body).encode("utf-8"),
        )
        raw_body = response["body"].read().decode("utf-8")
        payload = json.loads(raw_body)
        content = payload.get("content", [])
        if content and isinstance(content[0], dict) and "text" in content[0]:
            return str(content[0]["text"]).strip()
        raise LLMServiceError("Bedrock response did not include text content")
    except (ClientError, BotoCoreError) as exc:
        raise LLMServiceError(f"Failed to invoke Bedrock model '{model_id}'") from exc
    except (UnicodeDecodeError, json.JSONDecodeError, KeyError, TypeError) as exc:
        raise LLMServiceError("Invalid payload returned by Bedrock model") from exc
