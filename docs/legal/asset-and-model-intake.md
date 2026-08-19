# Asset and model intake

Assets and models are separate rights-bearing inputs, not automatically covered by the GGEN Apache license.

## Required receipt

Before an asset or model can enter a public or commercial artifact, record:

- stable ID, purpose, format, dimensions/contract and exact size;
- immutable source URL, upstream version/commit and SHA-256;
- SPDX license identifier, full license/notice and copyright owner;
- whether it is modified, derived, trained, fine-tuned or generated;
- redistribution, commercial-use, embedding and attribution permission;
- privacy/classification and user-data restrictions;
- security/model-card or parser-risk review;
- approved destinations and reviewer/evidence reference.

Do not invent a license from a filename or an upstream project name. Pending or unknown provenance blocks distribution.

## Protected pack

The private RGEN asset pack is not Apache-2.0 licensed by this repository. The public registry at `config/protected-asset-registry.json` contains metadata and digests without exposing bytes. A verified pack may be installed only by an owner-approved workflow that checks the exact registry entries, size, digest and canonical relative path. The public build must remain functional and must report protected features as unavailable when the pack is absent. It must never download restricted bytes automatically.

Protected assets are immutable at the byte level. Do not optimize, re-encode, migrate, train on, or modify them through ordinary public tooling.
