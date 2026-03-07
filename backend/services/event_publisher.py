"""Event publishing abstractions for domain events."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)


class EventPublisher:
    """Publishes domain events to the configured event bus.

    This repository currently provides a logging-based implementation to keep
    infrastructure concerns decoupled from API logic.
    """

    def publish(self, event_name: str, payload: dict[str, Any]) -> None:
        logger.info("Publishing event %s", event_name, extra={"payload": payload})


publisher = EventPublisher()
