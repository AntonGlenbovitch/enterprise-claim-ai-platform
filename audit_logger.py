"""Utilities for persisting audit logs for claim processing calls."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


@dataclass(slots=True)
class AuditLogEntry:
    """Represents one auditable model interaction for a claim."""

    claim_id: str
    model_used: str
    retrieved_docs: list[Any]
    prompt: str
    response: str
    timestamp: str

    @classmethod
    def build(
        cls,
        claim_id: str,
        model_used: str,
        retrieved_docs: Iterable[Any],
        prompt: str,
        response: str,
        timestamp: str | None = None,
    ) -> "AuditLogEntry":
        return cls(
            claim_id=claim_id,
            model_used=model_used,
            retrieved_docs=list(retrieved_docs),
            prompt=prompt,
            response=response,
            timestamp=timestamp or datetime.now(timezone.utc).isoformat(),
        )


class AuditLogger:
    """Writes audit entries to newline-delimited JSON (JSONL)."""

    def __init__(self, log_file: str | Path = "audit_logs.jsonl") -> None:
        self.log_file = Path(log_file)
        self.log_file.parent.mkdir(parents=True, exist_ok=True)

    def log(
        self,
        claim_id: str,
        model_used: str,
        retrieved_docs: Iterable[Any],
        prompt: str,
        response: str,
        timestamp: str | None = None,
    ) -> AuditLogEntry:
        entry = AuditLogEntry.build(
            claim_id=claim_id,
            model_used=model_used,
            retrieved_docs=retrieved_docs,
            prompt=prompt,
            response=response,
            timestamp=timestamp,
        )
        with self.log_file.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(asdict(entry), ensure_ascii=False) + "\n")
        return entry


__all__ = ["AuditLogEntry", "AuditLogger"]
