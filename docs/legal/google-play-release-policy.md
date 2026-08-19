# Google Play release policy

Google Play distribution requires a separately reviewed Android release profile. Apache-2.0 source licensing alone is not Play approval.

Before submission, record the exact application identity, non-debug production signing receipt, target/compile SDK, supported devices, privacy policy/data-safety answers, permissions justification, content declarations, artifact hash, SBOM and review sign-off.

Use Android Storage Access Framework, MediaStore and app-private storage for normal document/image access. Do not request all-files access or broad permissions without a documented policy requirement and owner/legal review. Network and remote AI behavior must be optional, disclosed, consented and covered by data handling/retention controls. API keys must live in platform secure storage and must not enter settings exports, projects, logs, crash reports or artifacts.

The release must not include unresolved Lucida/font rights, signatures, institutional or government marks, protected templates, unreviewed OCR/model binaries or private user data. Protected packs are owner-supplied and private; they are not automatically Play-distributable.

Important Android, performance, touch/stylus, storage, process-death, thermal and backend claims require raw evidence from the authoritative Redmi Turbo 4 Pro device. No emulator or desktop result substitutes for that evidence.
