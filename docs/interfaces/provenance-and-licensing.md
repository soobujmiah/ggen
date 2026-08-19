# Provenance and licensing contracts

`ggen_core` treats license, source and protected-asset state as domain data rather than build-time comments.

## Contracts

- `SpdxExpression` validates a reviewed allow-list plus `LicenseRef-*` identifiers and simple `AND`/`OR` expressions. The allow-list is deliberately incomplete and grows only through intake review; an unknown name is rejected rather than guessed.
- `LicenseDescriptor` records review state, SPDX expression, copyright owner, license-text receipt, private-use approval, redistribution, commercial-use and attribution flags. A pending, unknown or blocked review cannot grant public distribution.
- `SourceReceipt` records HTTPS source URL, version, immutable 40-character commit, lowercase SHA-256 and positive byte size.
- `AssetProvenance` records a stable ID, canonical relative pack path, purpose, source receipt, license descriptor, private-pack requirement and protected availability state.
- `DistributionEligibility` distinguishes public eligibility, private-only use, blocked rights and blocked provenance.
- `ProtectedAssetAvailability` distinguishes no pack, present-but-unverified, verified private-only, owner-approved workflow availability and unresolved-rights blocking.

The contracts do not read files, download assets or grant rights. The public registry remains metadata-only. The explicit verifier is responsible for checking a supplied private pack's exact paths, sizes and SHA-256 values; a successful digest check is integrity evidence, not a license.

The domain package is platform-neutral: it imports no Flutter, Android, filesystem, network, provider, model or protected-asset implementation.
