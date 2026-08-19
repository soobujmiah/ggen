# Third-party notices

The public repository currently contains GGEN-owned platform-neutral source, documentation, governance scripts and registry metadata. No protected RGEN bytes, production templates, signatures, seals, logos, fonts, OCR data or model binaries are included.

The `ggen_core` package declares development dependencies in `packages/ggen_core/pubspec.yaml`. Their exact locked versions, source receipts and current intake status are recorded in `config/provenance/dependencies.json`. A dependency is not cleared for commercial distribution merely because it is available from a package registry; its license and notice must be reviewed at release intake.

The public registry in `config/protected-asset-registry.json` contains hashes and metadata only. It does not grant rights to obtain, copy, modify or redistribute the corresponding private asset-pack bytes.

Before a release, generate and review an SBOM, preserve license texts/notices, and block any dependency, model or asset with unknown provenance or distribution rights. See `docs/legal/dependency-intake.md`, `docs/legal/asset-and-model-intake.md`, and `docs/legal/sbom-and-provenance.md`.
