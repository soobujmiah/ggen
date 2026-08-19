#!/usr/bin/env python3
"""Print a reproducible source receipt for the current Git commit."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def main() -> int:
    tracked = git("ls-files", "-z").encode("utf-8")
    receipt = {
        "repository": "soobujmiah/ggen",
        "source_commit": git("rev-parse", "HEAD"),
        "tree": git("rev-parse", "HEAD^{tree}"),
        "clean_worktree": not bool(git("status", "--porcelain")),
        "tracked_file_count": len(tracked.split(b"\0")) - 1,
        "tracked_path_list_sha256": hashlib.sha256(tracked).hexdigest(),
    }
    print(json.dumps(receipt, indent=2, sort_keys=True))
    return 0 if receipt["clean_worktree"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
