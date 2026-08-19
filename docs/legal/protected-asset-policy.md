# Protected asset policy

The private protected asset vault is [`soobujmiah/ggen-protected-assets`](https://github.com/soobujmiah/ggen-protected-assets). It preserves owner-approved RGEN history and restricted bytes. It must remain private.

The public repository contains only [`config/protected-asset-registry.json`](../../config/protected-asset-registry.json): stable logical IDs, expected sizes, SHA-256 digests, purposes, source repository/commit, license status, public distribution status and required-private state. It contains no protected bytes.

## Availability states

- `UNAVAILABLE_NO_PACK`: no owner-supplied pack is installed;
- `PACK_PRESENT_UNVERIFIED`: bytes exist but have not passed verification;
- `PACK_VERIFIED_PRIVATE_ONLY`: all registry entries match and the pack remains private;
- `AVAILABLE_FOR_APPROVED_OWNER_WORKFLOW`: an explicit owner policy permits the operation;
- `DISTRIBUTION_BLOCKED_RIGHTS_UNRESOLVED`: rights or authorization are not established.

The general application and tests must work in `UNAVAILABLE_NO_PACK`. A protected feature must fail closed and visibly when verification is missing. It must never silently substitute a different asset, auto-download restricted files, serialize them into projects/logs, or upload them to AI providers.

The verifier accepts an explicit pack root, rejects missing/extra entries, canonical-path violations, size mismatches and SHA-256 mismatches, and performs no writes. It does not grant a license. The pack is never modified, optimized, re-encoded, migrated or used as a public sample.
