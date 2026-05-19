"""RAG retrieval helpers for policy document context via OpenSearch vector search."""

from __future__ import annotations

import json
import os
from typing import Any

from opensearchpy import OpenSearch
from opensearchpy.exceptions import OpenSearchException

_OPENSEARCH_HOST_ENV = "OPENSEARCH_HOST"
_OPENSEARCH_PORT_ENV = "OPENSEARCH_PORT"
_OPENSEARCH_INDEX_ENV = "OPENSEARCH_POLICY_INDEX"
_OPENSEARCH_VECTOR_FIELD_ENV = "OPENSEARCH_VECTOR_FIELD"
_OPENSEARCH_TEXT_FIELD_ENV = "OPENSEARCH_TEXT_FIELD"
_POLICY_QUERY_VECTOR_ENV = "POLICY_QUERY_VECTOR"

_DEFAULT_PORT = 9200
_DEFAULT_INDEX = "policy-documents"
_DEFAULT_VECTOR_FIELD = "embedding"
_DEFAULT_TEXT_FIELD = "content"
_DEFAULT_TOP_K = 5


class PolicyRetrievalError(RuntimeError):
    """Raised when policy context retrieval from OpenSearch fails."""


def _build_client() -> OpenSearch:
    host = os.getenv(_OPENSEARCH_HOST_ENV)
    if not host:
        raise PolicyRetrievalError(f"Environment variable {_OPENSEARCH_HOST_ENV} is required")

    port = int(os.getenv(_OPENSEARCH_PORT_ENV, str(_DEFAULT_PORT)))
    return OpenSearch(hosts=[{"host": host, "port": port}])


def _parse_query_vector(query_vector: list[float] | None) -> list[float]:
    if query_vector is not None:
        return query_vector

    vector_from_env = os.getenv(_POLICY_QUERY_VECTOR_ENV)
    if not vector_from_env:
        raise PolicyRetrievalError(
            "A query vector is required via the query_vector argument or POLICY_QUERY_VECTOR"
        )

    try:
        parsed_vector = json.loads(vector_from_env)
    except json.JSONDecodeError as exc:
        raise PolicyRetrievalError("POLICY_QUERY_VECTOR must be valid JSON") from exc

    if not isinstance(parsed_vector, list) or not parsed_vector:
        raise PolicyRetrievalError("POLICY_QUERY_VECTOR must be a non-empty JSON array")

    try:
        return [float(value) for value in parsed_vector]
    except (TypeError, ValueError) as exc:
        raise PolicyRetrievalError("POLICY_QUERY_VECTOR values must be numbers") from exc


def retrieve_policy_context(
    query_vector: list[float] | None = None,
    top_k: int = _DEFAULT_TOP_K,
) -> list[dict[str, Any]]:
    """Retrieve top policy documents using OpenSearch vector search.

    Args:
        query_vector: Embedding vector to search against. If omitted, this is read
            from the ``POLICY_QUERY_VECTOR`` environment variable (JSON array).
        top_k: Number of top documents to return.

    Returns:
        List of document dictionaries including ``id``, ``score``, and document fields.
    """

    vector = _parse_query_vector(query_vector)
    index_name = os.getenv(_OPENSEARCH_INDEX_ENV, _DEFAULT_INDEX)
    vector_field = os.getenv(_OPENSEARCH_VECTOR_FIELD_ENV, _DEFAULT_VECTOR_FIELD)
    text_field = os.getenv(_OPENSEARCH_TEXT_FIELD_ENV, _DEFAULT_TEXT_FIELD)

    search_query: dict[str, Any] = {
        "size": top_k,
        "query": {
            "knn": {
                vector_field: {
                    "vector": vector,
                    "k": top_k,
                }
            }
        },
        "_source": [text_field, "title", "policy_id", "section"],
    }

    try:
        client = _build_client()
        response = client.search(index=index_name, body=search_query)
        hits = response.get("hits", {}).get("hits", [])
    except OpenSearchException as exc:
        raise PolicyRetrievalError("OpenSearch query failed during policy context retrieval") from exc

    documents: list[dict[str, Any]] = []
    for hit in hits:
        source = hit.get("_source", {})
        documents.append(
            {
                "id": hit.get("_id"),
                "score": hit.get("_score"),
                **source,
            }
        )

    return documents
