from __future__ import annotations

import json

from app.infrastructure.persistence.redis_chat_session_repository import RedisChatSessionRepository


class FakeRedis:
    def __init__(self):
        self.values = {}

    def set(self, key, value):
        self.values[key] = value

    def get(self, key):
        return self.values.get(key)


def test_redis_chat_session_repository_round_trips_context(monkeypatch):
    fake = FakeRedis()

    class FakeRedisFactory:
        @staticmethod
        def from_url(*args, **kwargs):
            return fake

    monkeypatch.setattr("app.infrastructure.persistence.redis_chat_session_repository.redis.Redis", FakeRedisFactory)

    repo = RedisChatSessionRepository(redis_url="redis://test/0")
    repo.create(
        "session-1",
        {"symptoms": ["cough"], "state": "INITIAL", "seeded_from_assessment": True, "lang": "ar"},
    )

    assert repo.get("session-1") == {
        "symptoms": ["cough"],
        "state": "INITIAL",
        "seeded_from_assessment": True,
        "lang": "ar",
    }
    assert json.loads(fake.values["symptom_chat:session:session-1"])["symptoms"] == ["cough"]


def test_redis_chat_session_repository_returns_none_for_missing_session(monkeypatch):
    fake = FakeRedis()

    class FakeRedisFactory:
        @staticmethod
        def from_url(*args, **kwargs):
            return fake

    monkeypatch.setattr("app.infrastructure.persistence.redis_chat_session_repository.redis.Redis", FakeRedisFactory)

    repo = RedisChatSessionRepository(redis_url="redis://test/0")

    assert repo.get("missing") is None
