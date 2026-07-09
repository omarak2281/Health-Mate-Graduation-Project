from __future__ import annotations

from typing import Literal

Urgency = Literal["low", "moderate", "high", "critical"]

# Ordering used to enforce the plan's §2.1 composition rule: the rule engine can only
# escalate urgency, the ML classifier (wired in later phases) can never downgrade it.
_URGENCY_RANK: dict[Urgency, int] = {"low": 0, "moderate": 1, "high": 2, "critical": 3}


def max_urgency(a: Urgency, b: Urgency) -> Urgency:
    return a if _URGENCY_RANK[a] >= _URGENCY_RANK[b] else b
