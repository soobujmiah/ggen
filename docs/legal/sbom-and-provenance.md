# SBOM and build provenance

Every public or commercial artifact must be traceable to:

- repository and exact source commit;
- clean-tree status and relevant review/decision;
- pinned toolchain profile;
- complete dependency/model/asset receipts;
- generated SBOM and license/notice bundle;
- security/dependency scan results and tool versions;
- build command/profile and signing identity class;
- artifact filename, size and SHA-256;
- limitations and device evidence, when applicable.

GitHub Actions and releases are the canonical artifact/evidence locations. A local result is provisional until committed as a receipt or reproduced in the canonical workflow. If Actions cannot start because of account billing or spending limits, record that exact operational status and run dependency-free checks locally; do not call the source code verified by an unavailable job.

The public registry may record a protected asset's expected hash without containing its bytes. A private pack receipt must never be copied into a public artifact unless distribution rights have been approved.
