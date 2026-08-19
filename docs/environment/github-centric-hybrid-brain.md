# GitHub-centric hybrid development brain

## Decision

GGEN uses a **hybrid brain**:

- **GitHub is canonical memory and control plane.** Source, specifications, ADRs, issues, manifests, reviews, CI results, artifacts, and releases live there.
- **Arena Agent workspace is the orchestration brain.** It audits, plans, writes architecture/docs/source, performs lightweight checks, and drives GitHub through APIs. It is not durable infrastructure.
- **GitHub Codespaces is the primary interactive build environment** once provisioned.
- **GitHub Actions is the reproducible build/test/release farm** once billing is restored.
- **Redmi Turbo 4 Pro is the physical Android truth source** for UX, storage, thermals, memory, and acceleration evidence.
- **Optional heavy workers** may later run large 3D rendering, fuzzing, or AI jobs under explicit privacy policy.

The machine-readable contract is [`config/development-environments.yaml`](../../config/development-environments.yaml).

## Current Arena machine inspection

Observed 2026-08-19:

| Area | Result |
|---|---|
| OS | Debian GNU/Linux 13 (trixie), x86_64, KVM |
| CPU | 2 logical Xeon threads at reported 2.60 GHz |
| RAM | 1.9 GiB total, no swap |
| Workspace disk | 25 GiB total, ~20 GiB available at inspection |
| Persistent workspace | `/home/user` only; installed dependencies/caches are disposable |
| Available | Git 2.47.3, Python 3.13.14, Node 20.20.2/npm 10.8.2, Java 11, GCC/G++ 14.2 |
| Missing | GitHub CLI, Flutter/Dart, Gradle, Android SDK/ADB, CMake/Ninja/Clang, Rust, Docker/Podman |

## Consequence

This Arena machine is well suited to architecture, audits, manifests, documentation, source generation, static analysis, and small tests. It is **not** the authoritative Flutter/Android/3D build machine. Full builds here would be fragile because RAM is under 2 GiB, swap is absent, and required toolchains are missing/disposable.

Durable output must be committed and pushed. Never rely on an installed package, background process, or path outside `/home/user` surviving.

## GitHub workflow

1. Requirement/idea enters an issue or master-spec change.
2. Arena reads repository state and produces a documented plan/ADR/PR branch.
3. Codespace or Actions uses pinned toolchain files to compile/test.
4. Artifacts carry source SHA, checksums, SBOM/provenance, and evidence metadata.
5. Redmi receives the exact CI artifact for physical validation.
6. Device report returns to GitHub and gates claims/releases.
7. Knowledge decisions update documentation before merge.

## Current blocker

Historical GitHub Actions runs were rejected because the account reported failed payments or an insufficient spending limit. Public governance run `32258736289` for commit `1760880d8b65f93b8d677645e5619b35d074a0bc` later completed successfully, including the reusable core test. Record any future interruption as an account/infrastructure result rather than a source-code result; never infer a green or failed claim without the exact run output.
