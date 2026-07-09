from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]

AUDITED_FILES = [
    REPO_ROOT / "Symptom-Checker" / "README.md",
    REPO_ROOT / "Symptom-Checker" / "app.py",
    REPO_ROOT / "Back-end" / "app" / "api" / "v1" / "ai.py",
    REPO_ROOT / "Back-end" / "app" / "services" / "ai_service.py",
    REPO_ROOT / "Front-end" / "health_mate_app" / "assets" / "translations" / "ar.json",
    REPO_ROOT / "Front-end" / "health_mate_app" / "assets" / "translations" / "en.json",
]

AUDITED_GLOBS = [
    REPO_ROOT / "Symptom-Checker" / "Data",
]

MOJIBAKE_MARKERS = (
    "\u00c3",  # Ã
    "\u00c2",  # Â
    "\u00d8",  # Ø
    "\u00d9",  # Ù
    "\u00e2\u20ac",  # â€...
    "\u00e2\u2020",  # â†...
    "\u00e2\u0153",  # âœ...
    "\u00f0\u0178",  # ðŸ...
)


def _audit_targets() -> list[Path]:
    targets = [path for path in AUDITED_FILES if path.exists()]
    for root in AUDITED_GLOBS:
        if root.exists():
            targets.extend(root.rglob("*.json"))
            targets.extend(root.rglob("*.js"))
    return sorted(set(targets))


def test_symptom_checker_phase10_files_are_utf8_without_bom_or_mojibake():
    failures: list[str] = []
    for path in _audit_targets():
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            failures.append(f"{path.relative_to(REPO_ROOT)} starts with a UTF-8 BOM")
            continue
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            failures.append(f"{path.relative_to(REPO_ROOT)} is not valid UTF-8: {exc}")
            continue
        marker = next((item for item in MOJIBAKE_MARKERS if item in text), None)
        if marker:
            failures.append(
                f"{path.relative_to(REPO_ROOT)} contains mojibake marker {marker.encode('unicode_escape').decode()}"
            )

    assert not failures, "\n".join(failures)
