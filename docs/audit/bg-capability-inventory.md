# BG reference capability inventory

**Audited source:** `soobujmiah/bg` @ `baaba2ad473d10d1c71f67b555494203f4d41e5f`  
**Use:** engineering reference only; no UI/design reuse.

## Reusable concepts

| Capability | Evidence | GGEN treatment |
|---|---|---|
| TFLite segmentation | Bundled MediaPipe-style model and interpreter | Adapter behind `ImageProcessor`; model must have provenance contract |
| Global + tiled inference | Source implementation | Preserve algorithm concept; re-establish tests and ownership |
| Mask feathering/refinement | Source implementation | Pure raster operation with golden masks |
| Background modes | Transparent/solid/blur source paths | Manual raster operation independent from AI |
| Adjust/rotate/flip | Source implementation | Core non-destructive operations |
| PNG/JPEG/WebP | MediaStore/export source | Export adapter with explicit fidelity |
| Graceful fallback | Interpreter candidate sequence | Keep failure containment; label fallback honestly |

## Must not reuse blindly

- API-level NPU/GPU detection.
- Delegate creation as execution evidence.
- requested/stale backend labels.
- fabricated 60/20/20 phase timings.
- in-memory settings/logs presented as durable.
- batch UI that processes only the first selected item.
- save-intermediate-then-upscale pipeline.
- broad/unneeded permissions and dependencies.
- cleanup outside `finally`/explicit bitmap ownership.
- average-color fallback presented as background removal quality.

## Integration boundary

GGEN Phase 3 will implement a new adapter against `ImageProcessor` and `ComputeEvidence`. No Compose screen, color, icon, component, or navigation code crosses the boundary.
