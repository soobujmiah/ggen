#!/usr/bin/env python3
"""Verify an explicit owner-supplied protected pack without including or changing it."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "config/protected-asset-registry.json"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def safe_child(root: Path, relative: str) -> Path:
    relative_path = Path(relative)
    if relative_path.is_absolute() or not relative_path.parts or ".." in relative_path.parts or any(part in {"", "."} for part in relative_path.parts):
        raise ValueError(f"unsafe registry path: {relative}")
    candidate = (root / relative_path).resolve()
    root_resolved = root.resolve()
    try:
        candidate.relative_to(root_resolved)
    except ValueError as error:
        raise ValueError(f"registry path escapes pack root: {relative}") from error
    return candidate


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pack-root",
        type=Path,
        help="Explicit private pack root containing the registry pack paths",
    )
    parser.add_argument(
        "--allow-vault-metadata",
        action="store_true",
        help="Allow the known private-vault README/manifests beside the asset paths",
    )
    args = parser.parse_args()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    assets = registry["assets"]
    if args.pack_root is None:
        print("Protected pack state: UNAVAILABLE_NO_PACK (integrity verification skipped; public build remains supported).")
        return 0
    root = args.pack_root
    if not root.is_dir():
        print(f"Protected pack verification FAILED: pack root is not a directory: {root}")
        return 1

    failures: list[str] = []
    expected_paths = {item["pack_path"] for item in assets}
    allowed_vault_metadata = {
        "rgen/README.md",
        "rgen/manifests/protected-assets-v1.csv",
        "rgen/manifests/protected-assets-v1.json",
        "rgen/manifests/protected-assets-v1.md",
    }
    actual_paths: set[str] = set()
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.is_symlink():
            failures.append(f"SYMLINK {path.relative_to(root)}")
            continue
        relative = path.relative_to(root).as_posix()
        if args.allow_vault_metadata and relative in allowed_vault_metadata:
            continue
        actual_paths.add(relative)
    for relative in sorted(expected_paths - actual_paths):
        failures.append(f"MISSING {relative}")
    for relative in sorted(actual_paths - expected_paths):
        failures.append(f"UNREGISTERED {relative}")

    for item in assets:
        relative = item["pack_path"]
        try:
            path = safe_child(root, relative)
        except ValueError as error:
            failures.append(str(error))
            continue
        if not path.is_file():
            continue
        if path.is_symlink():
            failures.append(f"SYMLINK {relative}")
            continue
        size = path.stat().st_size
        if size != item["size_bytes"]:
            failures.append(f"SIZE {relative}: observed size does not match registry")
            continue
        if digest(path) != item["sha256"]:
            failures.append(f"SHA256 {relative}: observed digest does not match registry")

    if failures:
        print("Protected pack verification FAILED:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"Protected pack state: PACK_VERIFIED_PRIVATE_ONLY ({len(assets)} files and {registry['total_size_bytes']} bytes match; no files changed).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
