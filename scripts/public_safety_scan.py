#!/usr/bin/env python3
"""Scan the complete reachable public Git history for restricted material."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_PREFIXES = ("protected/",)
FORBIDDEN_SUFFIXES = {
    ".ttf",
    ".otf",
    ".woff",
    ".woff2",
    ".traineddata",
    ".apk",
    ".aab",
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".bmp",
    ".tif",
    ".tiff",
    ".onnx",
    ".tflite",
    ".safetensors",
    ".pkl",
    ".pickle",
    ".bin",
}
SECRET_PATTERNS = (
    re.compile(rb"ghp_[A-Za-z0-9]{20,}"),
    re.compile(rb"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(rb"gho_[A-Za-z0-9]{20,}"),
    re.compile(rb"AKIA[0-9A-Z]{16}"),
    re.compile(rb"AIza[0-9A-Za-z_-]{20,}"),
    re.compile(rb"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(rb"xox[baprs]-[A-Za-z0-9-]{20,}"),
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
)
MAX_BLOB_BYTES = 2 * 1024 * 1024


def run(*args: str) -> bytes:
    return subprocess.check_output(args, cwd=ROOT)


def main() -> int:
    failures: list[str] = []
    lines = run("git", "rev-list", "--objects", "--all").decode("utf-8", errors="replace").splitlines()
    seen_objects: set[str] = set()
    scanned_blobs = 0
    for line in lines:
        object_id, _, path = line.partition(" ")
        if not path:
            continue
        normalized = path.replace("\\", "/")
        lower = normalized.lower()
        if any(lower.startswith(prefix) for prefix in FORBIDDEN_PREFIXES):
            failures.append(f"forbidden history path: {normalized}")
        if any(lower.endswith(suffix) for suffix in FORBIDDEN_SUFFIXES):
            failures.append(f"forbidden history extension: {normalized}")
        if object_id in seen_objects:
            continue
        seen_objects.add(object_id)
        metadata = subprocess.check_output(
            ["git", "cat-file", "--batch-check=%(objecttype) %(objectsize)"],
            input=(object_id + "\n").encode(),
            cwd=ROOT,
        ).decode("ascii", errors="replace").strip().split()
        if not metadata or metadata[0] != "blob":
            continue
        scanned_blobs += 1
        size = int(metadata[1])
        if size > MAX_BLOB_BYTES:
            failures.append(f"unexpectedly large public blob ({size} bytes): {normalized}")
            continue
        blob = run("git", "cat-file", "blob", object_id)
        for pattern in SECRET_PATTERNS:
            if pattern.search(blob):
                failures.append(f"secret-like pattern in history blob: {normalized}")
                break
        if b"\x00" in blob:
            failures.append(f"unexpected binary blob in public history: {normalized}")

    if failures:
        print("Public-safety history scan FAILED:")
        for failure in sorted(set(failures)):
            print(f"  {failure}")
        return 1
    print(f"Public-safety history scan passed: {len(lines)} reachable objects, {scanned_blobs} blobs, no restricted paths, binaries, large blobs or secret patterns.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
