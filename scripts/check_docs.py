#!/usr/bin/env python3
"""Dependency-free Markdown link and secret-pattern check."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"\[[^]]+\]\(([^)]+)\)")
SECRET = re.compile(
    r"(?:ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|gho_[A-Za-z0-9]{20,}|"
    r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|"
    r"AIza[0-9A-Za-z_-]{20,}|sk-[A-Za-z0-9_-]{20,})"
)


def main() -> int:
    failures: list[str] = []
    markdown = [p for p in ROOT.rglob("*.md") if ".git" not in p.parts]
    for path in markdown:
        text = path.read_text(encoding="utf-8")
        if SECRET.search(text):
            failures.append(f"secret-like pattern: {path.relative_to(ROOT)}")
        for match in LINK.finditer(text):
            target = match.group(1).split("#", 1)[0].strip()
            if not target or "://" in target or target.startswith(("mailto:", "tel:")):
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                failures.append(f"broken link: {path.relative_to(ROOT)} -> {target}")

    if failures:
        print("Documentation check FAILED:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"Documentation check passed: {len(markdown)} Markdown files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
