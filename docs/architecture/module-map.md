# Module ownership map

| Module family | Owns | Must not own |
|---|---|---|
| Domain | values, invariants, schemas, operations | Flutter, filesystem, network, vendor SDK |
| Application | use cases, orchestration, policy | rendering/native implementation |
| Job runtime | queue, limits, progress, cancel, resume, cleanup | UI widgets |
| Creative engines | deterministic vector/raster/document render/edit operations | cloud credentials/routing |
| Typography/font engine | shaping, glyphs, OpenType, font validation/export | protected-font mutation or UI widgets |
| Native 3D engine | scene evaluation, mesh/material/animation/render operations | Flutter application policy or credentials |
| AI API/router | capabilities, policy, request/evidence | provider-specific HTTP/SDK details |
| Providers/backends | one provider/runtime adapter | cross-provider routing |
| Import/export | format parsing/rendering + fidelity report | arbitrary storage access |
| Asset registry | metadata/version/dedup/provenance | secret keys |
| Protected RGEN | immutable reads and contract validation | writes/transforms/migration |
| Platform Android | SAF, Keystore, WorkManager, device/thermal | product/domain policy |
| Flutter app | original UI, input, accessibility | blocking processing |
| Plugins | versioned capability extensions | unrestricted host authority |
