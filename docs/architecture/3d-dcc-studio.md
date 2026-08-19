# Professional 3D DCC Studio

## Scope decision

GGEN has a long-term **full digital-content-creation (DCC) roadmap**: modeling, sculpting, UV, materials, rigging, animation, simulation, rendering and compositing. Blender is a quality reference for depth, reliability, shortcuts, non-destructive workflows and extensibility—not UI to copy and not an immediate feature-parity claim.

This subsystem must have GGEN's own interaction model and adaptive phone/tablet/desktop UX.

## Architectural boundary

Flutter owns application chrome, workspace state, commands, inspectors and accessibility. A native `ThreeDEngine` owns scene evaluation, geometry, acceleration structures, rendering and high-frequency viewport interaction. Engine choice is not locked in Phase 0; candidates may include a Rust/C++ core with Vulkan/Metal/Direct3D/WebGPU-compatible abstraction and a reviewed Android viewport backend.

The UI communicates through stable command/event/snapshot interfaces. It does not copy full meshes every frame across a slow bridge.

## Scene model

- scenes, collections, objects and stable IDs;
- transforms, parenting, constraints and dependency graph;
- meshes, curves, surfaces, text, cameras, lights, volumes and instances;
- modifiers and non-destructive stack;
- materials, textures, node graphs and color management;
- animation clips/actions, keyframes, curves, drivers and NLA-style sequencing;
- armatures, bones, skinning, shape keys and constraints;
- render layers/passes and compositing graph;
- asset links, versions, proxies/LODs and provenance;
- extension data that round-trips unknown plugin nodes.

## Professional tool roadmap

### Modeling

Selection modes, transform/orientation/pivots, snapping, extrusion/inset/bevel/loop cuts, merge/dissolve, normals, topology tools, booleans, subdivision, retopology, curves/surfaces, procedural modifiers and geometry-node-style graph.

### Sculpting and painting

Multires/dynamic topology strategy, masks/face sets, remesh, symmetry, professional brush engine reuse, texture/vertex/weight painting, tablet pressure/tilt, undo and memory budgets.

### UV and materials

UV unwrap/seams/islands/packing, UDIM strategy, PBR materials, texture painting/baking, shader graph, previews, ICC/OCIO-compatible color-management plan.

### Rigging and animation

Armatures, IK/FK/constraints, skin/weights, shape keys, timeline/dope sheet/curve editor, drivers, clips/NLA, motion paths and audio/video synchronization where supported.

### Simulation

Rigid/soft body, cloth, particles, hair, fluid/smoke and collision are later capability plugins. Each declares deterministic limits, cache location, backend, cancellation and unsupported mobile conditions.

### Rendering and compositing

- real-time viewport with progressive quality/LOD;
- physically based offline renderer roadmap with CPU/GPU backend evidence;
- sampling, denoise, lighting, camera/depth, render passes;
- compositing node graph and image sequence/video output;
- checkpointable tiles and optional privacy-approved remote workers.

## Interchange

Prioritize bounded glTF 2.0 import/export, then OBJ/STL/PLY and reviewed USD strategy. Native project remains authoritative. Blender `.blend` is not a stable public interchange contract; Blender integration should use glTF/USD/Alembic or an explicit reviewed headless Blender worker/plugin rather than reverse-engineering `.blend` blindly.

## Android/phone reality

- provide viewport LOD, occlusion/culling, progressive loading and proxy assets;
- resource admission for vertices, indices, textures, nodes, bones and animation keys;
- device-loss/context-loss recovery and autosaved scene journal;
- touch/stylus-first manipulation plus mouse/keyboard workflows;
- heavy render/simulation may use an explicit local or remote worker, but manual scene editing and basic rendering remain offline-capable;
- vendor Vulkan availability is not assumed. Backend is verified per device/build.

## Evidence and performance

Measure frame time percentiles, input-to-feedback latency, scene evaluation, draw/triangle counts, GPU/CPU memory, shader compilation, load/save, render samples/time, thermals and fallback. “Blender quality” may be used only as a roadmap quality bar; releases list exact implemented operations and tested limits.

## Testing

Scene graph/dependency determinism, mesh topology/property tests, modifiers, import/export round trips and fidelity reports, shader goldens, animation/rigging fixtures, malicious model/texture limits, device/GPU loss, cancellation/recovery, viewport frame budgets and physical Redmi evidence. Cross-check exported glTF using independent validators/renderers.

## Phasing

1. Native engine feasibility spike: scene graph, camera/light/PBR cube, glTF, picking, transform, frame metrics.
2. Mesh modeling, modifiers, materials, UV, asset system.
3. sculpt/paint/retopology and professional 3D brush integration.
4. rigging/animation and timeline/graph editors.
5. offline rendering/compositing and worker protocol.
6. procedural geometry, simulations, production interoperability and plugin expansion.

Each stage must be useful and honest before the next. Full DCC is a multi-phase program, not one feature ticket.
