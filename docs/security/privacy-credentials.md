# Privacy and credential policy

- Manual/local operation requires no network.
- Provider keys live in Android Keystore-backed secure storage through opaque references.
- Logs, diagnostics, project exports, workflows, crash reports, and plugin settings redact credentials and user content by default.
- Before remote AI: show destination/provider/model, data categories, transforms, estimated cost, retention/policy link, and whether output may be stored by provider; obtain policy-appropriate approval.
- Per-project/content classification can force local-only.
- Protected RGEN assets never upload automatically.
- No telemetry/analytics until a separate opt-in ADR defines exact fields, retention, and deletion.
