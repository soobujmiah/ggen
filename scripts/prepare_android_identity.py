#!/usr/bin/env python3
"""Normalize the generated Android wrapper identity to "ggen".

The manual APK workflow generates a temporary Android wrapper with
`flutter create --project-name=ggen_app`, which would install the app
with the launcher label "ggen_app" and process name
"com.example.ggen_app". This script rewrites the generated wrapper so
the device-facing app identity is exactly "ggen":

- AndroidManifest.xml: android:label -> "ggen"
- build.gradle(.kts):  applicationId -> "com.example.ggen"

The Dart package identifier (pubspec name "ggen_app") and the
Kotlin/namespace stay internal and are not user-visible; the launcher
label and the Android process name (applicationId) are the user-facing
identity and are what this script normalizes.

Idempotent: re-running on an already-normalized wrapper is a no-op.
Fails loudly when a pattern is missing, so CI never silently ships an
APK with the wrong name.

Usage: prepare_android_identity.py <path-to-android-dir>
"""

import re
import sys
from pathlib import Path

APP_LABEL = "ggen"
APPLICATION_ID = "com.example.ggen"

_LABEL_RE = re.compile(r'(<application\b[^>]*\bandroid:label=")[^"]*(")')
_APPLICATION_ID_RE = re.compile(
    r'(applicationId\s*(?:=\s*)?")[^"]*(")'
)


def normalize_manifest(manifest: Path) -> bool:
    text = manifest.read_text(encoding="utf-8")
    updated, count = _LABEL_RE.subn(rf"\g<1>{APP_LABEL}\g<2>", text)
    if count == 0:
        raise SystemExit(
            f"prepare_android_identity: no android:label found in "
            f"{manifest}; refusing to ship an unnamed APK."
        )
    if updated != text:
        manifest.write_text(updated, encoding="utf-8")
        print(f"  manifest label -> {APP_LABEL} ({manifest})")
    return updated != text


def normalize_build_file(build_file: Path) -> bool:
    if not build_file.exists():
        return False
    text = build_file.read_text(encoding="utf-8")
    updated, count = _APPLICATION_ID_RE.subn(
        rf"\g<1>{APPLICATION_ID}\g<2>", text
    )
    if count == 0:
        raise SystemExit(
            f"prepare_android_identity: no applicationId found in "
            f"{build_file}; refusing to ship an APK with a wrong process name."
        )
    if updated != text:
        build_file.write_text(updated, encoding="utf-8")
        print(f"  applicationId -> {APPLICATION_ID} ({build_file})")
    return updated != text


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(
            "usage: prepare_android_identity.py <path-to-android-dir>"
        )
    android_dir = Path(sys.argv[1])
    manifest = android_dir / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        raise SystemExit(
            f"prepare_android_identity: {manifest} not found; was the "
            f"Android wrapper generated?"
        )

    changed = False
    changed |= normalize_manifest(manifest)
    for name in ("build.gradle", "build.gradle.kts"):
        changed |= normalize_build_file(android_dir / "app" / name)

    if changed:
        print("Android app identity normalized to ggen.")
    else:
        print("Android app identity already ggen; no changes.")


if __name__ == "__main__":
    main()
