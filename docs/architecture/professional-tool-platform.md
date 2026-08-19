# Professional Tool Platform Architecture

## Goal

Avoid building isolated demo tools. Every vector, raster, painting, font, 3D, document and PDF operation must plug into one professional foundation.

## Shared tool contract

A `ToolDescriptor` declares stable ID/version, studio/domain, interaction modes, parameters/schema/defaults, input/output node types, destructive/non-destructive behavior, preview mode, resource estimate, history strategy, shortcut/gesture hooks, capability requirements, evidence state and documentation reference.

A `ToolSession` owns input snapshot, mutable preview state, coalesced pointer/stylus events, cancellation, parameter changes and commit. Only `commit()` creates one reversible domain command. Cancelling restores the exact pre-tool state.

## Shared engines

- geometry/vector kernel;
- tiled raster and brush engine;
- typography/shaping/font engine;
- native 3D scene/render engine;
- UDM/document/PDF engine;
- color management and asset registry;
- job/runtime/resource admission;
- commands/history/autosave/recovery;
- import/export/fidelity reports;
- plugin/workflow/AI entry points.

## Input abstraction

Normalize pointer, mouse buttons/wheel, keyboard, touch gestures and stylus pressure/tilt/azimuth/hover into capability-tagged events. Never synthesize unsupported pressure/tilt as evidence. Tool logic consumes normalized events; platform adapters own raw Android APIs.

## Presets and customization

Parameters are typed and versioned. Presets contain tool ID/version, only valid parameter values, provenance and optional device mappings. Shortcut/gesture profiles are separate from creative values. Migration fails visibly when semantics changed.

## Frame and task architecture

High-frequency preview runs in the appropriate rendering/native engine. Flutter receives lightweight state/events, not full image/mesh copies per frame. Heavy operations become jobs with progressive preview, cancellation and transactional commit.

## Quality gate

The release checklist in `docs/product/computer-quality-tool-standard.md` is mandatory for every tool. A beautiful icon or visible button does not count as implementation.
