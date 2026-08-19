#!/usr/bin/env python3
"""Validate GGEN's public/private GitHub-centric development contract."""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/development-environments.yaml"
TOOL_QUALITY = ROOT / "config/tool-quality-standard.yaml"
SECRET_VALUE = re.compile(
    r"(?:ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|gho_[A-Za-z0-9]{20,}|"
    r"sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)"
)


def require(mapping: dict, key: str, context: str):
    if key not in mapping:
        raise ValueError(f"missing {context}.{key}")
    return mapping[key]


def main() -> int:
    raw = CONTRACT.read_text(encoding="utf-8")
    if SECRET_VALUE.search(raw):
        raise ValueError("environment contract contains a credential-like value")
    data = yaml.safe_load(raw)
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        raise ValueError("unsupported environment contract schema")

    project = require(data, "project", "root")
    if project.get("repository") != "soobujmiah/ggen":
        raise ValueError("public repository must be soobujmiah/ggen")
    if project.get("repository_visibility") != "public":
        raise ValueError("public source repository must remain public")
    if project.get("protected_asset_vault") != "soobujmiah/ggen-protected-assets":
        raise ValueError("protected asset vault must remain the private GGEN vault")
    if project.get("protected_asset_vault_visibility") != "private":
        raise ValueError("protected asset vault must remain private")
    if project.get("development_model") != "github_centric_hybrid_brain":
        raise ValueError("development model must remain github_centric_hybrid_brain")

    brains = require(data, "brains", "root")
    for role in ("arena_agent", "github", "redmi_turbo_4_pro", "github_codespace", "heavy_worker"):
        require(brains, role, "brains")

    principles = require(data, "principles", "root")
    required_true = (
        "github_is_source_of_truth",
        "local_workspaces_are_disposable",
        "no_unpushed_authoritative_state",
        "protected_assets_are_immutable",
        "reference_repositories_are_read_only",
        "claims_require_evidence",
    )
    false_principles = [name for name in required_true if principles.get(name) is not True]
    if false_principles:
        raise ValueError(f"required principles not true: {false_principles}")

    boundary = require(data, "public_private_boundary", "root")
    if boundary.get("public_pack_bytes") != "forbidden" or boundary.get("automatic_restricted_asset_download") != "forbidden":
        raise ValueError("public/private asset boundary is not fail-closed")
    if boundary.get("absent_private_pack_general_build") != "supported":
        raise ValueError("general build must support an absent private pack")

    routing = require(data, "task_routing", "root")
    if routing.get("physical_android_tests") != "redmi_turbo_4_pro":
        raise ValueError("physical Android tests must route to the Redmi profile")

    evidence = require(data, "evidence_policy", "root")
    forbidden = set(require(evidence, "forbidden", "evidence_policy"))
    for rule in ("fabricated_timing", "backend_inference_from_api_availability", "marketing_claim_from_compile_success"):
        if rule not in forbidden:
            raise ValueError(f"missing forbidden evidence rule: {rule}")

    quality_raw = TOOL_QUALITY.read_text(encoding="utf-8")
    if SECRET_VALUE.search(quality_raw):
        raise ValueError("tool quality contract contains a credential-like value")
    quality = yaml.safe_load(quality_raw)
    if not isinstance(quality, dict) or quality.get("schema_version") != 1:
        raise ValueError("unsupported tool quality schema")
    policy = require(quality, "policy", "tool_quality")
    for rule in ("computer_quality_mandatory", "mobile_friendly_ui_mandatory", "manual_operation_required", "reference_ui_copying_forbidden", "fewer_complete_tools_over_many_demo_tools"):
        if policy.get(rule) is not True:
            raise ValueError(f"mandatory tool quality rule is not true: {rule}")
    gates = set(require(quality, "required_gates", "tool_quality"))
    for gate in ("exact_numeric_control", "undo_redo_transaction", "keyboard_mouse_touch_stylus_specification", "accessible_alternative_for_every_gesture", "tests_documentation_and_evidence"):
        if gate not in gates:
            raise ValueError(f"missing mandatory tool gate: {gate}")

    print("Environment and tool-quality contracts verified: public source/private vault, GitHub hybrid brain, computer-quality capabilities and mandatory mobile-friendly UI.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
