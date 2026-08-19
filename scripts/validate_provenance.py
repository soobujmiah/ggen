#!/usr/bin/env python3
"""Validate dependency, asset and model provenance records."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")


def load(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def lock_package_names() -> set[str]:
    names: set[str] = set()
    in_packages = False
    for line in (ROOT / "packages/ggen_core/pubspec.lock").read_text(encoding="utf-8").splitlines():
        if line == "packages:":
            in_packages = True
            continue
        if in_packages and line.startswith("sdks:"):
            break
        if in_packages:
            match = re.match(r"^  ([A-Za-z0-9_]+):$", line)
            if match:
                names.add(match.group(1))
    return names


def main() -> int:
    failures: list[str] = []
    dependency_data = load("config/provenance/dependencies.json")
    records = dependency_data.get("records", [])
    recorded_names = {item.get("name") for item in records}
    missing = sorted(lock_package_names() - recorded_names)
    if missing:
        failures.append(f"locked packages without provenance records: {missing}")
    if len(recorded_names) != len(records):
        failures.append("dependency provenance contains duplicate or missing package names")
    for item in records:
        name = item.get("name", "<unnamed>")
        for key in ("version", "source_url", "source_commit_status", "artifact_sha256", "license_status", "review_status"):
            if not item.get(key):
                failures.append(f"dependency {name} missing {key}")
        if item.get("source_url") and not item["source_url"].startswith("https://"):
            failures.append(f"dependency {name} source URL is not HTTPS")
        if not isinstance(item.get("artifact_sha256"), str) or not SHA256.fullmatch(item["artifact_sha256"]):
            failures.append(f"dependency {name} has invalid artifact SHA-256")
        if item.get("license_status") in {"UNKNOWN", "PENDING_INDEPENDENT_REVIEW"} and item.get("distribution_eligibility") == "approved":
            failures.append(f"dependency {name} is approved while license status is unresolved")

    registry = load("config/protected-asset-registry.json")
    assets = registry.get("assets", [])
    if registry.get("asset_count") != len(assets):
        failures.append("protected registry count mismatch")
    for item in assets:
        identity = item.get("id", "<unnamed asset>")
        if not SHA256.fullmatch(str(item.get("sha256", ""))):
            failures.append(f"asset {identity} has invalid SHA-256")
        if not COMMIT.fullmatch(str(item.get("source_commit", ""))):
            failures.append(f"asset {identity} has invalid source commit")
        if not item.get("source_repository") or not item.get("purpose") or not item.get("license_status"):
            failures.append(f"asset {identity} lacks provenance or license status")
        if item.get("public_distribution") != "blocked":
            failures.append(f"asset {identity} is not distribution blocked")

    public_files = [path for path in ROOT.rglob("*") if path.is_file() and ".git" not in path.parts]
    for path in public_files:
        if path.suffix.lower() in {".ttf", ".otf", ".woff", ".woff2", ".traineddata", ".onnx", ".tflite", ".safetensors"}:
            failures.append(f"public tree contains an unregistered model/font: {path.relative_to(ROOT)}")

    if failures:
        print("Provenance validation FAILED:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"Provenance validation passed: {len(records)} locked dependency receipts and {len(assets)} protected metadata receipts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
