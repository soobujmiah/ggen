# GGEN Flutter application shell

This is the first platform surface for GGEN. It is deliberately a small, original, manual-first shell around the platform-neutral `ggen_core` contracts.

Current scope:

- adaptive compact/tablet/desktop layout;
- tool rail, canvas area, inspector and status bar;
- no protected assets, provider calls, persistence or production claims.

Run in GitHub Codespaces with the pinned toolchain from the repository root:

```bash
cd apps/ggen_app
flutter test
```

Android build and Redmi Turbo 4 Pro testing are intentionally separate evidence stages.
