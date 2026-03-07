"""Utilities to flag potential hallucinations against retrieved context documents."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Mapping, Sequence

_SENTENCE_SPLIT_PATTERN = re.compile(r"(?<=[.!?])\s+|\n+")
_TOKEN_PATTERN = re.compile(r"\b[a-zA-Z0-9']+\b")
_DEFAULT_TEXT_KEYS = ("content", "text", "body", "document")


@dataclass(frozen=True)
class HallucinationCheckResult:
    """Structured result of hallucination checking."""

    hallucination_detected: bool
    support_ratio: float
    supported_sentences: list[str] = field(default_factory=list)
    unsupported_sentences: list[str] = field(default_factory=list)
    supporting_documents: dict[str, str] = field(default_factory=dict)


def _normalize_whitespace(text: str) -> str:
    return " ".join(text.split())


def _tokenize(text: str) -> set[str]:
    return {token.lower() for token in _TOKEN_PATTERN.findall(text)}


def _split_sentences(text: str) -> list[str]:
    cleaned = _normalize_whitespace(text)
    if not cleaned:
        return []
    chunks = [part.strip() for part in _SENTENCE_SPLIT_PATTERN.split(cleaned)]
    return [chunk for chunk in chunks if chunk]


def _extract_document_text(document: str | Mapping[str, Any]) -> str:
    if isinstance(document, str):
        return document

    for key in _DEFAULT_TEXT_KEYS:
        value = document.get(key)
        if isinstance(value, str) and value.strip():
            return value

    return ""


def compare_llm_output_with_documents(
    llm_output: str,
    retrieved_documents: Sequence[str | Mapping[str, Any]],
    *,
    min_token_overlap: int = 3,
    min_overlap_ratio: float = 0.35,
    min_sentence_tokens: int = 5,
) -> HallucinationCheckResult:
    """Compare LLM output against retrieved documents to detect likely hallucinations.

    A sentence is considered supported when it has sufficient token overlap with
    at least one retrieved document.
    """

    if not isinstance(llm_output, str) or not llm_output.strip():
        raise ValueError("llm_output must be a non-empty string")

    if min_token_overlap < 1:
        raise ValueError("min_token_overlap must be >= 1")

    if not 0 < min_overlap_ratio <= 1:
        raise ValueError("min_overlap_ratio must be in (0, 1]")

    documents = [_extract_document_text(doc) for doc in retrieved_documents]
    document_pairs = [(doc, _tokenize(doc)) for doc in documents if doc.strip()]

    if not document_pairs:
        sentences = _split_sentences(llm_output)
        return HallucinationCheckResult(
            hallucination_detected=bool(sentences),
            support_ratio=0.0,
            unsupported_sentences=sentences,
        )

    supported_sentences: list[str] = []
    unsupported_sentences: list[str] = []
    supporting_documents: dict[str, str] = {}

    for sentence in _split_sentences(llm_output):
        sentence_tokens = _tokenize(sentence)

        if len(sentence_tokens) < min_sentence_tokens:
            supported_sentences.append(sentence)
            continue

        best_overlap_count = 0
        best_overlap_ratio = 0.0
        best_document = ""

        for raw_document, tokens in document_pairs:
            overlap_count = len(sentence_tokens & tokens)
            overlap_ratio = overlap_count / max(len(sentence_tokens), 1)

            if (
                overlap_count > best_overlap_count
                or (
                    overlap_count == best_overlap_count
                    and overlap_ratio > best_overlap_ratio
                )
            ):
                best_overlap_count = overlap_count
                best_overlap_ratio = overlap_ratio
                best_document = raw_document

        if (
            best_overlap_count >= min_token_overlap
            and best_overlap_ratio >= min_overlap_ratio
        ):
            supported_sentences.append(sentence)
            supporting_documents[sentence] = best_document
        else:
            unsupported_sentences.append(sentence)

    total_sentences = len(supported_sentences) + len(unsupported_sentences)
    support_ratio = (
        len(supported_sentences) / total_sentences if total_sentences else 0.0
    )

    return HallucinationCheckResult(
        hallucination_detected=bool(unsupported_sentences),
        support_ratio=support_ratio,
        supported_sentences=supported_sentences,
        unsupported_sentences=unsupported_sentences,
        supporting_documents=supporting_documents,
    )
