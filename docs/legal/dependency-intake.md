# Dependency intake

No dependency is admitted to a distributable build by name alone.

## Required receipt

Record one entry in the provenance register for every direct dependency and every separately distributed transitive/runtime dependency that the build includes:

- stable package or component ID and ecosystem;
- exact version and lockfile receipt;
- immutable source URL and upstream commit/tag where available;
- downloaded artifact size and SHA-256;
- SPDX license identifier, license text and required notices;
- copyright owner and modification/patch state;
- security/advisory review status;
- intended product use and distribution eligibility;
- review date, reviewer and evidence location.

A floating branch, an unverified archive, a package without a license receipt, or an unresolved notice is not release eligible. Unknown license means distribution blocked; do not guess an SPDX identifier.

## Automation

`config/provenance/dependencies.json` is the machine-readable receipt for the current small `ggen_core` dependency set. Governance checks validate that records exist and have immutable version/hash/source fields. A future build environment must generate an SBOM and vulnerability report; a missing tool is recorded as an operational blocker, not reported as a clean scan.

Do not copy dependency source or license files into GGEN unless the intake review requires it. Preserve the dependency's own license and notices in the product artifact when distribution permits.
