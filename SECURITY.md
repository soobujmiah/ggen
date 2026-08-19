# Security policy

Report suspected vulnerabilities privately through GitHub's private vulnerability reporting or an owner-approved private channel. Do not open a public issue containing credentials, user documents, signatures, private asset bytes, model data or malicious proof files.

All imported files are untrusted and must pass bounded staging, canonical-path, resource-admission and parser policies. Credentials must remain in platform secure storage and must not enter projects, settings exports, logs or artifacts. Protected asset packs remain private, are never auto-downloaded, and are verified by exact manifest size and SHA-256 before an owner-approved operation.

Security fixes must include a regression test or an honest explanation of why a test is not yet possible. See `docs/security/import-and-resource-policy.md`, `docs/security/privacy-credentials.md`, and `docs/legal/google-play-release-policy.md`.
