#!/usr/bin/env python3
"""Fail closed on debug signing defaults and serialized credential values."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SUFFIXES = {".dart", ".kt", ".kts", ".java", ".gradle", ".gradle.kts", ".xml", ".json", ".yaml", ".yml", ".py", ".sh"}
DEBUG_SIGNING = re.compile(r"signingConfigs?\.debug|storePassword\s*[=:]\s*[\"']android[\"']", re.IGNORECASE)
SERIALIZED_SECRET = re.compile(
    r"(?:api[_-]?key|access[_-]?token|client[_-]?secret|private[_-]?key)\s*[:=]\s*[\"'](?!secure:|ref:|ENV:|<)[^\"']{8,}[\"']",
    re.IGNORECASE,
)


def main() -> int:
    failures: list[str] = []
    scanned = 0
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts or path.suffix.lower() not in SOURCE_SUFFIXES:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        scanned += 1
        if DEBUG_SIGNING.search(text):
            failures.append(f"debug signing or fallback password in {path.relative_to(ROOT)}")
        if SERIALIZED_SECRET.search(text):
            failures.append(f"credential-like literal serialized in {path.relative_to(ROOT)}")

    if failures:
        print("Build-security check FAILED:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"Build-security check passed: scanned {scanned} source/config files; no debug signing defaults or serialized credential literals.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
