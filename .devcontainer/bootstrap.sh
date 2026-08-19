#!/usr/bin/env bash
set -euo pipefail

# Codespaces-only bootstrap. It is intentionally not invoked by local checks.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$root/config/toolchain.yaml"
flutter_version="$(sed -n 's/^  version: \([^ ]*\)$/\1/p' "$config" | head -n1)"
flutter_sha256="$(sed -n 's/^  linux_x64_sha256: \([^ ]*\)$/\1/p' "$config" | head -n1)"
archive="/tmp/flutter_linux_${flutter_version}-stable.tar.xz"
install_root="$HOME/.local/share/ggen"

if [[ -z "$flutter_version" || -z "$flutter_sha256" ]]; then
  echo "Unable to read the pinned Flutter version or checksum from $config" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1 || [[ "$(flutter --version 2>/dev/null | sed -n '1s/Flutter \([^ ]*\).*/\1/p')" != "$flutter_version" ]]; then
  mkdir -p "$install_root"
  curl --fail --location --retry 3 --output "$archive"     "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${flutter_version}-stable.tar.xz"
  echo "${flutter_sha256}  ${archive}" | sha256sum --check --status
  rm -rf "$install_root/flutter"
  tar -xJf "$archive" -C "$install_root"
  rm -f "$archive"
  grep -qxF 'export PATH="$HOME/.local/share/ggen/flutter/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null ||     echo 'export PATH="$HOME/.local/share/ggen/flutter/bin:$PATH"' >> "$HOME/.bashrc"
  export PATH="$install_root/flutter/bin:$PATH"
fi

flutter --version
flutter config --no-analytics
