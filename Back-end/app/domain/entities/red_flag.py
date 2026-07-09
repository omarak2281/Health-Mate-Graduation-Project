from __future__ import annotations

from pydantic import BaseModel


class RedFlag(BaseModel):
    """A triggered red flag. `code` is stable across languages (Plan §11: caregiver
    notification tests assert identical `code`s across ar/en runs) and equals the
    triggering symptom's taxonomy id.
    """

    code: str
    symptom_id: str
    severity: int
