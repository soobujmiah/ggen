#!/usr/bin/env python3
"""push_skb_registry — deterministic, zero-LLM synchronization of a repository's .repo/ state into SKB.

Reads the local .repo/project.yaml and STATUS.md, builds a machine-readable registry entry,
and pushes it to the canonical SKB repository so that every participant's current mechanical
state is available in one authoritative location without any agent needing to manually copy it.

Usage (inside a participating repository's CI):
    python3 scripts/push_skb_registry.py --project-id songjog

Environment:
    GITHUB_TOKEN  — write access to the target SKB repository (required when pushing).
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

PROJECT_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")
DEFAULT_SKB_REPO = "soobujmiah/skb"


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# Reading helpers
# ---------------------------------------------------------------------------

def load_yaml(path: Path) -> dict[str, Any] | None:
    try:
        import yaml
    except ImportError:
        print(f"ERROR: PyYAML not installed; cannot read {path}", file=sys.stderr)
        return None
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def get_commit_sha(root: Path) -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True,
    )
    return result.stdout.strip() or None if result.returncode == 0 else None


def get_short_sha(root: Path) -> str:
    sha = get_commit_sha(root)
    return (sha[:7] if sha else "unknown")


# ---------------------------------------------------------------------------
# Payload builder
# ---------------------------------------------------------------------------

def build_payload(
    project_id: str,
    project_yaml: dict[str, Any],
    status_md: str | None,
    participation: str,
) -> dict[str, Any]:
    """Build the machine-readable registry entry from .repo/project.yaml + local metadata."""
    head = project_yaml.get("head", {})
    build_block = project_yaml.get("build", {})
    test_block = project_yaml.get("test", {})
    sync_block = project_yaml.get("sync", {})
    phases = project_yaml.get("phases", {})

    sync_status = sync_block.get("status", "ok")
    failed_at = None
    failure_reason = None
    if sync_status == "failed":
        failed_at = sync_block.get("last_synced_at")
        # Capture any error metadata the originating repo may have stored
        error_meta = project_yaml.get("sync_error", {})
        failure_reason = error_meta.get("reason") if isinstance(error_meta, dict) else None

    payload: dict[str, Any] = {
        "schema": "skb.repo-registry/v1",
        "project_id": project_id,
        "repository": project_yaml.get("repository", ""),
        "participation": participation,
        "synchronized_at": now_iso(),
        "head": {
            "commit": head.get("commit", ""),
            "branch": head.get("branch", ""),
            "committed_at": head.get("committed_at"),
        },
        "build": {
            "status": build_block.get("status", "unknown"),
            "run_id": build_block.get("run_id"),
            "at": build_block.get("at"),
        },
        "test": {
            "status": test_block.get("status", "unknown"),
            "run_id": test_block.get("run_id"),
            "summary": test_block.get("summary"),
        },
        "last_successful_build": project_yaml.get("last_successful_build"),
        "last_failed_build": project_yaml.get("last_failed_build"),
        "phases": {
            "source": phases.get("source", "not_configured"),
            "completed": phases.get("completed", []),
            "active": phases.get("active"),
            "next": phases.get("next"),
        },
        "sync": {
            "status": sync_status,
            "attempted_at": sync_block.get("last_synced_at"),
            "source": sync_block.get("source", "local"),
        },
    }
    if status_md:
        payload["status_summary"] = status_md.strip()
    if failed_at or failure_reason:
        payload["sync"]["failure"] = {
            "failed_at": failed_at,
            "reason": failure_reason,
        }
    return payload


# ---------------------------------------------------------------------------
# GitHub API write helpers
# ---------------------------------------------------------------------------

def _gh_api(method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    args = [
        "gh", "api", f"/{path}",
        "--method", method,
        "--fields", "*",
    ]
    if body is not None:
        args.extend(["--input", "-"])
    env = {**subprocess.os.environ, "GIT_TERMINAL_PROMPT": "0"}
    proc = subprocess.run(
        args,
        input=json.dumps(body) if body else "",
        capture_output=True, text=True, env=env,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"gh api {method} {path} failed (exit {proc.returncode}):\n{proc.stderr}")
    return json.loads(proc.stdout)


def _file_exists(skb_repo: str, path: str, ref: str = "HEAD") -> bool:
    result = subprocess.run(
        ["gh", "api", f"/repos/{skb_repo}/contents/{path}", "-f", "sha={ref}"],
        capture_output=True, text=True,
        env={**subprocess.os.environ, "GIT_TERMINAL_PROMPT": "0"},
    )
    return result.returncode == 0


def write_file_via_gh(
    skb_repo: str,
    path: str,
    content: str,
    message: str,
    branch: str = "main",
    sha: str | None = None,
) -> dict[str, Any]:
    """Create or update a file in the SKB repository via the GitHub API."""
    encoded = subprocess.run(
        ["git", "ls-remote", "--heads", skb_repo, branch],
        capture_output=True, text=True, env={**subprocess.os.environ, "GIT_TERMINAL_PROMPT": "0"},
    )
    if encoded.returncode != 0:
        raise RuntimeError(f"Could not resolve branch {branch} in {skb_repo}")

    current_sha = sha
    if current_sha is None and _file_exists(skb_repo, path, branch):
        info = _gh_api("GET", f"repos/{skb_repo}/contents/{path}", {"ref": branch})
        current_sha = info.get("sha")

    body = {
        "message": message,
        "content": (content.encode("utf-8")).hex(),
        "branch": branch,
    }
    if current_sha:
        body["sha"] = current_sha

    result = _gh_api("PUT", f"repos/{skb_repo}/contents/{path}", body)
    return result  # contains commit.sha, content.path, etc.


# ---------------------------------------------------------------------------
# Prose append helper
# ---------------------------------------------------------------------------

PROSE_HEADER = "<!-- deterministic state — managed by scripts/push_skb_registry.py. Do not hand-edit. -->"


def append_deterministic_section(prose_path: Path, payload: dict[str, Any]) -> str | None:
    """Append the deterministic-state section to an existing projects/state/<id>.md without
    overwriting human-authored narrative below it. Returns None if nothing changed.
    """
    if not prose_path.exists():
        return None

    text = prose_path.read_text(encoding="utf-8")
    fm_end = 0
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if m:
        fm_end = m.end()

    if PROSE_HEADER in text:
        return None  # already present; idempotent skip

    lines: list[str] = []
    build = payload.get("build", {})
    test = payload.get("test", {})
    head = payload.get("head", {})
    lsb = payload.get("last_successful_build")
    lfb = payload.get("last_failed_build")

    lines.append(PROSE_HEADER)
    lines.append("")
    lines.append(f"- Head: `{head.get('commit', '')}` on `{head.get('branch', '')}`")
    lines.append(f"- Build: **{build.get('status', 'unknown')}**")
    lines.append(f"- Test: **{test.get('status', 'unknown')}**")
    if build.get("at"):
        lines.append(f"- Last build: {build['at']}")
    if test.get("at"):
        lines.append(f"- Last test: {test['at']}")
    if lsb:
        lines.append(f"- Last successful build: `{lsb.get('commit', '')}` at {lsb.get('at', '')}")
    if lfb:
        lines.append(f"- Last failed build: `{lfb.get('commit', '')}` at {lfb.get('at', '')}")
    lines.append("")

    if fm_end > 0:
        new_text = text[:fm_end] + "\n".join(lines) + "\n" + text[fm_end:]
    else:
        new_text = "\n".join(lines) + "\n" + text

    return new_text


# ---------------------------------------------------------------------------
# Main CLI
# ---------------------------------------------------------------------------

def cmd_push(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    project_id = args.project_id
    skb_repo = args.skb_repo

    # Validate project_id
    if not PROJECT_ID_PATTERN.match(project_id):
        print(f"ERROR: project_id '{project_id}' does not match ^[a-z0-9][a-z0-9-]*$", file=sys.stderr)
        return 1

    # Read local state
    project_yaml_path = root / ".repo" / "project.yaml"
    project_yaml = load_yaml(project_yaml_path)
    if project_yaml is None:
        print(f"ERROR: {project_yaml_path} not found; run repo-knowledge sync first", file=sys.stderr)
        return 1

    status_md_path = root / ".repo" / "STATUS.md"
    status_md = status_md_path.read_text(encoding="utf-8") if status_md_path.exists() else None

    participation = "active"
    if args.participation:
        participation = args.participation

    payload = build_payload(project_id, project_yaml, status_md, participation)

    # Write to SKB
    try:
        token = subprocess.os.environ.get("GITHUB_TOKEN", "") or subprocess.os.environ.get("GH_TOKEN", "")
        if not token:
            raise RuntimeError("GITHUB_TOKEN not set")

        # Registry JSON
        registry_path = f"projects/registry/{project_id}.json"
        registry_content = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
        write_file_via_gh(skb_repo, registry_path, registry_content,
                          f"chore(skb): sync registry state for {project_id} from {get_short_sha(root)}")
        print(f"WROTE {registry_path}")

        # Projects/state prose update
        prose_path = f"projects/state/{project_id}.md"
        new_prose = append_deterministic_section(Path(prose_path), payload)
        if new_prose:
            write_file_via_gh(skb_repo, prose_path, new_prose,
                              f"chore(skb): append deterministic state for {project_id}")
            print(f"APPENDED deterministic section to {prose_path}")
        else:
            print(f"SKIPPED {prose_path} (section already present)")

        # Update index
        index_path = "projects/registry/index.json"
        if _file_exists(skb_repo, index_path):
            index_info = _gh_api("GET", f"repos/{skb_repo}/contents/{index_path}")
            existing_index = json.loads(bytes.fromhex(index_info["content"]).decode("utf-8"))
            existing_index["generated_at"] = now_iso()
            entries = existing_index.get("repositories", [])
            found = False
            for entry in entries:
                if entry.get("project_id") == project_id:
                    entry["last_synced_at"] = payload.get("synchronized_at", "")
                    entry["participation"] = participation
                    found = True
                    break
            if not found:
                entries.append({
                    "project_id": project_id,
                    "repository": payload.get("repository", ""),
                    "participation": participation,
                    "last_synced_at": payload.get("synchronized_at", ""),
                })
            entries.sort(key=lambda e: e.get("project_id", ""))
            index_content = json.dumps(existing_index, indent=2, ensure_ascii=False) + "\n"
            write_file_via_gh(skb_repo, index_path, index_content,
                              f"chore(skb): refresh registry index for {project_id}")
            print(f"UPDATED {index_path}")

        print(f"SYNC OK for {project_id} -> {skb_repo}")
        return 0

    except RuntimeError as exc:
        print(f"SYNC FAILED: {exc}", file=sys.stderr)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="push_skb_registry",
        description=__doc__,
    )
    parser.add_argument("--root", default=".", help="participating repository root (default: cwd)")
    parser.add_argument("--project-id", required=True, help="project slug matching ^[a-z0-9][a-z0-9-]*$")
    parser.add_argument("--skb-repo", default=DEFAULT_SKB_REPO,
                        help=f"owner/repo of the SKB registry target (default: {DEFAULT_SKB_REPO})")
    parser.add_argument("--participation", choices=["active", "retired", "skipped"], default="active",
                        help="participation status to record (default: active)")
    parser.set_defaults(func=cmd_push)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
