#!/usr/bin/env python3
"""Validate the public repository's legal and public/private boundary files."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_FILES = (
    "LICENSE",
    "NOTICE",
    "COPYRIGHT.md",
    "TRADEMARKS.md",
    "THIRD_PARTY_NOTICES.md",
    "docs/legal/licensing-policy.md",
    "docs/legal/dependency-intake.md",
    "docs/legal/asset-and-model-intake.md",
    "docs/legal/contributor-ip-policy.md",
    "docs/legal/commercial-release-policy.md",
    "docs/legal/google-play-release-policy.md",
    "docs/legal/sbom-and-provenance.md",
    "docs/legal/protected-asset-policy.md",
    "config/licensing.yaml",
    "config/protected-asset-registry.json",
    "config/provenance/dependencies.json",
)
SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")


def text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []
    for relative in REQUIRED_FILES:
        path = ROOT / relative
        if not path.is_file():
            failures.append(f"missing required legal/provenance file: {relative}")

    if failures:
        print("Legal-file check FAILED:")
        for failure in failures:
            print(f"  {failure}")
        return 1

    license_text = text("LICENSE")
    if "Apache License" not in license_text or "Version 2.0, January 2004" not in license_text:
        failures.append("LICENSE is not the Apache License 2.0 text")
    if "END OF TERMS AND CONDITIONS" not in license_text:
        failures.append("LICENSE is incomplete: end marker missing")

    config = text("config/licensing.yaml")
    for required in (
        "spdx: Apache-2.0",
        "unknown_license_distribution: blocked",
        "apache_licensed: false",
        "auto_download: false",
        "dco_signoff_required: true",
    ):
        if required not in config:
            failures.append(f"config/licensing.yaml missing required policy: {required}")

    registry = json.loads(text("config/protected-asset-registry.json"))
    assets = registry.get("assets")
    if registry.get("schema_version") != 1 or not isinstance(assets, list):
        failures.append("protected asset registry has an unsupported shape")
        assets = []
    if registry.get("asset_count") != len(assets):
        failures.append("protected asset registry asset_count does not match entries")
    if registry.get("total_size_bytes") != sum(item.get("size_bytes", -1) for item in assets):
        failures.append("protected asset registry total_size_bytes does not match entries")
    ids: set[str] = set()
    paths: set[str] = set()
    for index, item in enumerate(assets):
        prefix = f"registry asset {index}"
        for key in (
            "id",
            "pack_path",
            "size_bytes",
            "sha256",
            "purpose",
            "source_repository",
            "source_commit",
            "license_status",
            "public_distribution",
            "required_private_pack",
        ):
            if key not in item:
                failures.append(f"{prefix} missing {key}")
        asset_id = item.get("id")
        pack_path = item.get("pack_path")
        if not isinstance(asset_id, str) or not asset_id or asset_id in ids:
            failures.append(f"{prefix} has a missing or duplicate stable ID")
        else:
            ids.add(asset_id)
        if not isinstance(pack_path, str) or not pack_path or pack_path.startswith("/") or ".." in Path(pack_path).parts:
            failures.append(f"{prefix} has an unsafe pack path")
        elif pack_path in paths:
            failures.append(f"{prefix} has a duplicate pack path")
        else:
            paths.add(pack_path)
        if not isinstance(item.get("size_bytes"), int) or item["size_bytes"] < 0:
            failures.append(f"{prefix} has an invalid size")
        if not isinstance(item.get("sha256"), str) or not SHA256.fullmatch(item["sha256"]):
            failures.append(f"{prefix} has an invalid SHA-256")
        if not isinstance(item.get("source_commit"), str) or not COMMIT.fullmatch(item["source_commit"]):
            failures.append(f"{prefix} has an invalid source commit")
        if item.get("public_distribution") != "blocked":
            failures.append(f"{prefix} is not blocked from public distribution")
        if item.get("required_private_pack") is not True:
            failures.append(f"{prefix} is not marked private-pack required")

    dependencies = json.loads(text("config/provenance/dependencies.json"))
    records = dependencies.get("records")
    if dependencies.get("schema_version") != 1 or not isinstance(records, list) or not records:
        failures.append("dependency provenance register is empty or unsupported")
        records = []
    dependency_ids: set[str] = set()
    for index, item in enumerate(records):
        prefix = f"dependency record {index}"
        identifier = item.get("id")
        if not isinstance(identifier, str) or not identifier or identifier in dependency_ids:
            failures.append(f"{prefix} has a missing or duplicate ID")
        else:
            dependency_ids.add(identifier)
        for key in ("name", "version", "source_url", "source_commit_status", "artifact_sha256", "license_status", "review_status"):
            if not item.get(key):
                failures.append(f"{prefix} missing {key}")
        if item.get("source_url") and not str(item["source_url"]).startswith("https://"):
            failures.append(f"{prefix} source URL is not HTTPS")
        if not isinstance(item.get("artifact_sha256"), str) or not SHA256.fullmatch(item["artifact_sha256"]):
            failures.append(f"{prefix} has an invalid artifact SHA-256")
        if item.get("license_status") == "APPROVED" and not item.get("license_spdx"):
            failures.append(f"{prefix} is approved without an SPDX license")

    if failures:
        print("Legal-file check FAILED:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"Legal-file check passed: {len(REQUIRED_FILES)} required files, {len(assets)} protected registry records, {len(records)} dependency receipts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
