# RGEN reference capability inventory

**Audited source:** `soobujmiah/rgen` @ `250da99f92b280c1373aea23dafce856638043c9`  
**Use:** functional/reference engine knowledge plus owner-approved immutable private assets; no UI/design reuse. The public source contains metadata only; the private vault is a separate repository.

## Reusable concepts

- page/template validation and vector-first PDF composition;
- certificate, routine, testimonial field contracts;
- measured geometry instead of visual approximation;
- CSV/XLSX mapping and serial/pattern fields;
- text/image/photo/signature/shape/QR/barcode elements;
- Python/Dart parity and rendered regression artifacts;
- portable package concept with authenticated encryption;
- OCR language pair and exact artifact hashes;
- layout tests for spacing, columns, page size, coordinates, and font metrics.

## Must not reuse blindly

- whole-archive in-memory import/decrypt/decode;
- absolute or `../` manifest paths;
- unbounded PDFs/images/fonts/pages/elements/rows/cells;
- batch ZIP retaining every PDF in memory;
- raw `/sdcard` path guessing and `MANAGE_EXTERNAL_STORAGE`;
- debug signing as release identity;
- proprietary/unresolved assets without distribution decision;
- implementation claim treated as device verification;
- schema version written but not enforced.

## Protected assets

The exact private snapshot is preserved in `soobujmiah/ggen-protected-assets`. Public hashes and logical IDs are authoritative in `config/protected-asset-registry.json`; adapters may read/validate an owner-supplied pack, never transform or rewrite those bytes.
