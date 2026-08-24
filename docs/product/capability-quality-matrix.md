# Capability and Quality Matrix

This is a benchmark and target-quality matrix. It is **not** a claim that every listed capability is implemented.

| Studio | Professional / Android reference class | Required GGEN foundations | First useful milestone | Long-term depth |
|---|---|---|---|---|
| Vector | Illustrator / Infinite Design / Concepts class | Bezier geometry, nodes, styles, transforms, snapping, artboards, SVG/PDF fidelity | select/draw/edit paths and shapes with exact inspector | booleans, appearance stack, symbols, patterns, advanced typography |
| Raster/photo | Photoshop / PicsArt class | tiled raster, layers, masks, blends, color, selections, filters, history | crop/transform/adjust/mask/layers/export | high-bit depth, retouch, smart/non-destructive filters, color management, AI tools |
| Painting | Infinite Painter class | low-latency stroke engine, stylus events, brush graph/presets, tiled canvas | pressure brush/eraser, layers, undo, canvas navigation | texture/scatter/wet media, symmetry, assistants, advanced blend dynamics |
| 3D DCC | Blender / Nomad Sculpt / Prisma3D class | native scene/render model, dependency graph, resource limits, glTF | PBR viewport, scene objects, picking/transforms, glTF | modeling/sculpt/UV/material/rig/animation/simulation/render/composite |
| Font | FontForge / professional type-editor class | shaping engine, font project schema, Bezier glyphs, OpenType validation | glyph browser, outline/metrics edit, shaping proof | kerning/classes/features, variable masters, validated multi-format export |
| Document | professional page-layout class | UDM, typography, pages/layers/styles, job/export | editable page with text/image/vector and PDF | masters/tables/data merge/preflight/print/color/accessibility |
| PDF | professional PDF editor class | bounded parser, object/fidelity model, signatures/security policy | inspect/annotate/reorder/merge/export safely | editable text/vector where representable, forms, redaction, preflight, tagged PDF |
| AI creative | provider-neutral local/cloud class | stable LAI capability contract, evidence, jobs/history, result provenance | optional reviewed operation returning editable result | generation/edit/reconstruction across image/document/font/3D/workflow |

## Android benchmark rule

Android applications are first-class evidence sources alongside professional desktop/web references. They are benchmark inputs, not dependencies. For each capability, research should compare the strongest relevant Android options and extract the best interaction patterns, feature boundaries, performance trade-offs and limitations before GGEN implementation decisions.

Examples already established in research include Infinite Design, Concepts, Vector Ink, TouchDraw, Infinite Painter, PicsArt, Nomad Sculpt, Prisma3D and relevant Android document/PDF/OCR/media tools. The list is not exhaustive; future research must expand it when a capability warrants broader coverage.

## Ownership rule

GGEN owns creative/document semantics, editing UX, artifact models, import/export and result presentation. LAI owns AI execution, local/cloud/custom providers, routing/failover, model runtime/lifecycle, privileged Android tools, permissions, agent execution and runtime evidence.

The GGEN AI layer is therefore an integration/client boundary, not a second provider router or inference runtime.

## Current repository evidence

At the current documented baseline, GGEN has an implemented Phase 1 core and a substantially implemented Phase 2 workspace/creative foundation. The current README and phase evidence are authoritative for exact feature maturity; this matrix must not override them.

The current Phase 2 evidence includes responsive workspace/canvas foundations, project persistence, Draw/Text/Select/multi-select/layers and related device-tested interactions. Real vector editing, full raster editing, production 3D, professional PDF editing and the broader AI creative suite remain future milestones unless separately validated by current source/evidence.

## Maturity vocabulary

Use only:
`IMPLEMENTED / VALIDATED / EXPERIMENTAL / PLANNED / BLOCKED / NOT_STARTED`.

Source presence is not validation. Hardware-dependent claims require device evidence. Research benchmarks are not implementation claims.

## Documentation gate

Before implementing a capability:
1. inspect the current source and tests;
2. research the relevant professional and Android tools;
3. identify GGEN-owned vs LAI-owned responsibility;
4. verify no duplicate subsystem exists;
5. define a bounded acceptance-tested slice;
6. update the relevant specification/current-state record;
7. implement only after the evidence supports the decision.
