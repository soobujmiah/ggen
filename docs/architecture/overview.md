# Architecture overview

## Shape

```text
Presentation shell (original Flutter UI)
  workspace · command palette · inspector · panels · accessibility
                         |
Application use cases / task runtime
  projects · undo/history · jobs · autosave · workflows · policy
                         |
Domain contracts
  Universal Document Model · raster/vector ops · assets · settings
  import/export · providers · compute evidence · plugins · provenance
             /                 |                    \
Platform adapters       Creative engines                 AI/provider adapters
Android storage/jobs    vector/raster/document/font/3D   local/cloud/custom
secure credentials      render/import/export/native DCC  CPU/GPU/NNAPI/QNN
                                  |
Protected RGEN adapter (read/validate only; no mutation)
```

## Dependency rules

1. Domain imports no Flutter, Android, vendor SDK, network client, or file path.
2. Features call use cases, never providers/codecs/vendor runtimes directly.
3. AI Router is the sole AI selection boundary.
4. Job Runtime owns cancellation, progress, resource admission, recovery, and evidence.
5. Importers produce validated staged data; they cannot write arbitrary paths.
6. Protected assets are accessed only through a read-only registry/adapter.
7. UI consumes immutable state and task events; heavy work never runs on the UI isolate.

## Proposed packages/modules

- `core_document`, `core_geometry`, `core_raster`, `core_vector`
- `core_font`, `core_scene3d`, `core_animation`, `core_material`
- `core_assets`, `core_settings`, `core_history`, `core_jobs`
- `core_security`, `core_provenance`, `core_evidence`
- `api_import_export`, `api_ai`, `api_plugins`, `api_workflow`
- `engine_document`, `engine_vector`, `engine_raster`, `engine_typography`
- `engine_3d_native`, `engine_render`, `engine_compositor`
- `adapter_bg`, `adapter_rgen_protected`, `adapter_blender_worker`
- `runtime_local_ai`, `provider_cloud_ai`, `provider_custom`
- `platform_android`, `app_flutter`

Names are architectural placeholders until Phase 1 package setup.
