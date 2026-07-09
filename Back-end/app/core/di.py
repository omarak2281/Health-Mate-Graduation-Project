"""Plan §3.1: `core/di.py`. Minimal FastAPI-`Depends`-compatible providers for the Phase 5
Clean Architecture layers — kept intentionally small (no DI framework) since the existing
codebase already wires everything through `Depends()` directly; this just gives the new
domain/application layers the same single place to construct their infrastructure
implementations, so route handlers stay thin and swapping an implementation (e.g. Phase 6's
Postgres taxonomy repo replacing the JSON one) touches one place.
"""
from __future__ import annotations

from functools import lru_cache

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.domain.interfaces.assessment_repository import AssessmentRepository
from app.domain.interfaces.chat_session_repository import ChatSessionRepository
from app.domain.interfaces.disease_classifier import DiseaseClassifier
from app.domain.interfaces.taxonomy_repository import TaxonomyRepository
from app.application.interfaces.assessment_phraser import AssessmentPhraser
from app.infrastructure.ml.disease_classifier_impl import LightGbmDiseaseClassifier
from app.infrastructure.ml.model_registry import get_model_registry
from app.infrastructure.phrasing.assessment_phraser import build_assessment_phraser
from app.infrastructure.persistence.json_taxonomy_repository import JsonTaxonomyRepository
from app.infrastructure.persistence.postgres_assessment_repository import PostgresAssessmentRepository
from app.infrastructure.persistence.redis_chat_session_repository import get_chat_session_repository


@lru_cache
def get_taxonomy_repository() -> TaxonomyRepository:
    return JsonTaxonomyRepository()


@lru_cache
def get_disease_classifier() -> DiseaseClassifier:
    return LightGbmDiseaseClassifier(get_model_registry())


@lru_cache
def get_assessment_phraser() -> AssessmentPhraser:
    return build_assessment_phraser()


def get_chat_sessions() -> ChatSessionRepository:
    return get_chat_session_repository()


def get_assessment_repository(db: AsyncSession = Depends(get_db)) -> AssessmentRepository:
    return PostgresAssessmentRepository(db)
