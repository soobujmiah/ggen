# Core contract sketches

These are language-neutral Phase 0 contracts, not implementation.

## Universal Document Model

`DocumentProject` → metadata, color/profile/units, ordered artboards/pages, assets, components, history root.  
`CanvasNode` sealed types → Group, VectorPath, RasterLayer, TextFrame, Shape, Table, Image, Code, SignatureReference, ComponentInstance, Mask, Adjustment.  
Every node has stable ID, transform, bounds, visibility/lock, opacity/blend, style, semantic role, provenance, and extension data.

Rules: immutable commands mutate through transactions; unknown extensions round-trip; exporter returns a fidelity report; no raw platform path in domain values.

## Image processing

`ImageProcessor.describeCapabilities()`  
`ImageProcessor.plan(request, resourceBudget)`  
`ImageProcessor.execute(plan, input, cancellation, progress)` → result + `ComputeEvidence`  
Operations declare input/output formats, deterministic behavior, memory estimate, backend eligibility, and fidelity.

## Import/export

`Importer.probe(boundedHeader)` → confidence/type  
`Importer.inspect(stagedSource, limits)` → manifest/risks/resource estimate  
`Importer.import(validatedSource, policy, cancellation)` → domain object + provenance  
`Exporter.assess(domainObject, target)` → fidelity report  
`Exporter.export(..., transactionalSink)` → artifact receipt

## Protected asset registry

`ProtectedAssetDescriptor` → ID, path key, size, SHA-256, type, purpose, source commit, version, license state.  
`ProtectedAssetReader.openVerified(id)` rechecks canonical path, size, digest and returns read-only bytes/stream. No writer API exists.
