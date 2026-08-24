# Architecture overview

## Shape

```text
Presentation shell (original Flutter UI)
  workspace · command palette · inspector · panels · accessibility
                         |
GGEN application/use-case layer
  projects · undo/history · creative jobs · autosave · workflows · policy
                         |
GGEN domain contracts
  Universal Document Model · raster/vector/document operations · assets
  typography · 3D scene model · import/export · creative provenance
                         |
                 Stable AI Capability Contract
                         |
                         ▼
                  LAI Runtime (external)
       local inference · cloud/custom providers · routing/failover
       CPU/GPU/NPU · model lifecycle · Android tools · agent runtime
                         |
                  execution result/events
                         |
                         ▼
                 GGEN result integration

Platform adapters and creative engines remain GGEN-owned:
Android storage/jobs · vector/raster/document/font/3D · render/import/export
```

## Dependency rules

1. GGEN domain imports no Flutter, Android, vendor SDK, network client, or file path.
2. Features call GGEN use cases, never AI providers/codecs/vendor runtimes directly.
3. GGEN does not own the canonical AI provider router, provider registry, credentials authority, local AI runtime, Android tool registry, permission authority, or agent runtime; these are LAI-owned.
4. GGEN may expose an AI client/integration adapter, but it consumes the stable LAI capability contract rather than implementing a second runtime.
5. GGEN application jobs own creative/document workflow concerns such as undo/history, autosave, document transformation and UI progress. LAI owns AI execution lifecycle, provider routing, runtime cancellation/recovery and runtime evidence.
6. Importers produce validated staged data; they cannot write arbitrary paths.
7. Protected assets are accessed only through a read-only registry/adapter where applicable.
8. UI consumes immutable state and task events; heavy work never runs on the UI isolate.

## GGEN-owned modules / concepts

- `core_document`, `core_geometry`, `core_raster`, `core_vector`
- `core_font`, `core_scene3d`, `core_animation`, `core_material`
- `core_assets`, `core_settings`, `core_history`, `core_jobs`
- `core_security`, `core_provenance`, `core_evidence`
- `api_import_export`, `api_ai`, `api_plugins`, `api_workflow`
- `engine_document`, `engine_vector`, `engine_raster`, `engine_typography`
- `engine_3d_native`, `engine_render`, `engine_compositor`
- `platform_android`, `app_flutter`

## LAI integration boundary

`api_ai` is an integration contract/client boundary. It must not grow into a provider/runtime implementation inside GGEN.

The following remain canonical in LAI:

- local model execution;
- CPU/GPU/NPU backend selection and qualification;
- cloud/custom provider adapters;
- provider registry/routing/failover;
- API secret/credential authority;
- model lifecycle for runtime models;
- Android tool registry and privileged execution;
- Accessibility/Shizuku authority;
- agent planning/execution;
- runtime audit and execution evidence.

GGEN remains independently useful without LAI. When LAI is unavailable, non-AI creative/document workflows continue to function.

## Architectural status

Module names are architectural targets, not claims that every listed module currently exists. Implementation maturity must be taken from live source/tests and the current-state documentation, not from this overview alone.
