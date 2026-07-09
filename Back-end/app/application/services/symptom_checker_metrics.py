"""In-process rollout metrics for the structured symptom-checker flow.

These counters are intentionally lightweight and dependency-free. They give the graduation
rollout a concrete monitoring surface while keeping the old flow available as fallback.
"""
from __future__ import annotations

from collections import Counter
from threading import Lock

from app.application.dto.assessment_dto import AssessmentResultDTO


class SymptomCheckerRolloutMetrics:
    def __init__(self) -> None:
        self._lock = Lock()
        self._assessment_count = 0
        self._red_flag_count = 0
        self._caregiver_notification_count = 0
        self._latency_ms_total = 0.0
        self._latency_ms_max = 0.0
        self._top_prediction_distribution: Counter[str] = Counter()
        self._urgency_distribution: Counter[str] = Counter()

    def record_assessment(
        self,
        result: AssessmentResultDTO,
        *,
        latency_ms: float,
        caregiver_notified: bool,
    ) -> None:
        top_prediction = result.top_predictions[0].disease_id if result.top_predictions else "none"
        with self._lock:
            self._assessment_count += 1
            self._red_flag_count += 1 if result.red_flags else 0
            self._caregiver_notification_count += 1 if caregiver_notified else 0
            self._latency_ms_total += latency_ms
            self._latency_ms_max = max(self._latency_ms_max, latency_ms)
            self._top_prediction_distribution[top_prediction] += 1
            self._urgency_distribution[result.urgency] += 1

    def snapshot(self) -> dict:
        with self._lock:
            count = self._assessment_count
            average_latency = self._latency_ms_total / count if count else 0.0
            return {
                "assessment_count": count,
                "red_flag_trigger_rate": self._red_flag_count / count if count else 0.0,
                "caregiver_notification_rate": self._caregiver_notification_count / count if count else 0.0,
                "assessment_latency_ms_avg": round(average_latency, 2),
                "assessment_latency_ms_max": round(self._latency_ms_max, 2),
                "top_prediction_distribution": dict(self._top_prediction_distribution),
                "urgency_distribution": dict(self._urgency_distribution),
            }

    def reset(self) -> None:
        with self._lock:
            self._assessment_count = 0
            self._red_flag_count = 0
            self._caregiver_notification_count = 0
            self._latency_ms_total = 0.0
            self._latency_ms_max = 0.0
            self._top_prediction_distribution.clear()
            self._urgency_distribution.clear()


rollout_metrics = SymptomCheckerRolloutMetrics()
