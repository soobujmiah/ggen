# ADR-0002 — GitHub-centric hybrid brain

**Status:** Accepted by owner, 2026-08-19

## Context

GGEN is too broad for one transient machine. The current Arena environment is useful for agentic planning and lightweight work but has 2 CPU threads, 1.9 GiB RAM, no swap, and no Flutter/Android/native 3D toolchain. The Redmi is essential for physical truth but must not be the only source/build store. Reproducible builds and persistent knowledge are required.

## Decision

- GitHub is the sole canonical repository and lifecycle control plane.
- Arena is the orchestration/architecture/audit brain; all durable output is pushed.
- Codespaces becomes the pinned interactive development environment.
- Actions builds, tests, scans, packages, signs, and publishes.
- Redmi Turbo 4 Pro validates physical behavior and acceleration claims.
- Optional isolated workers may handle large rendering/AI workloads only through the job runtime and privacy router.

## Consequences

- No authoritative unpushed local state.
- Environment/toolchain contracts are versioned in YAML.
- Every artifact traces to commit and workflow.
- Physical-device evidence remains separate from CI.
- GitHub billing is an operational dependency and current blocker.
- A future offline continuity plan must export a complete Git bundle, docs, manifests, and protected assets so GitHub outage does not destroy ownership.
