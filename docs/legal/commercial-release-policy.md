# Commercial release policy

A commercial GGEN release is eligible only when the exact source commit, build profile, dependency graph, asset/model receipts, SBOM, security checks, license notices and artifact SHA-256 are recorded together.

## Blocking gates

- Apache-2.0 and all required legal files are present;
- every shipped dependency, asset and model has a provenance and license receipt;
- unknown or restricted distribution rights are absent from the artifact;
- the full Git history and tree pass public-safety scans;
- credentials, private data and protected bytes are absent;
- production signing uses controlled non-debug keys held outside the repository;
- the build is reproducible from the pinned toolchain as far as documented;
- import/resource/security tests and dependency vulnerability checks pass or have an explicitly approved risk record;
- the artifact, SBOM and evidence receipt are traceable to a commit and checksum;
- Android claims include required Redmi Turbo 4 Pro evidence where applicable.

A CI compile, desktop test or emulator run does not establish physical-device or backend verification. GitHub Actions billing failures are recorded as infrastructure/account blockers and do not become a false source-code pass.

Protected RGEN functionality is excluded from public/commercial artifacts unless each asset's rights and operator authorization are separately approved. A missing private pack is a supported product state, not a reason for the general build to fail.
