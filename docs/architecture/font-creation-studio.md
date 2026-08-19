# Premium Font Creation & Typography Studio

## Scope decision

GGEN will include a **full font-creation studio**, not only a text-formatting inspector. It is a phased professional subsystem. “Premium” means standards-correct, non-destructive, validated, responsive, and suitable for serious type work—not a promise of immediate parity with mature dedicated font editors.

## Two connected layers

### Typography engine

Used by every GGEN document/vector/3D-text surface:

- Unicode and script-aware shaping;
- OpenType GSUB/GPOS features;
- kerning, ligatures, alternates, small caps, fractions;
- variable-font axes and named instances;
- bidirectional text, line breaking, language/script selection;
- Bangla-first shaping and conjunct behavior;
- text on path, area text, columns, baseline grids and optical alignment;
- font fallback with explicit missing-glyph report;
- color-font support strategy (COLR/CPAL, SVG, bitmap strikes) where feasible;
- consistent preview/export shaping and deterministic font embedding/subsetting.

A likely native shaping stack is HarfBuzz + FreeType or an equivalently reviewed engine behind `TypographyEngine`. Flutter's text engine is not assumed sufficient for editable font engineering or export fidelity.

### Font engineering workspace

- glyph set, Unicode mapping and production names;
- Bezier outline drawing and direct node/control editing;
- contours, components, anchors, guidelines and metrics;
- sidebearings and metric keys;
- kerning pairs, classes and exception handling;
- masters, interpolation compatibility and variable axes;
- OpenType feature editor and compiler diagnostics;
- mark/mkmk/cursive attachment and script-specific anchors;
- hinting strategy and instructions where supported;
- glyph layers, references, backgrounds and version history;
- proof sheets, waterfall/specimen, shaping test strings and comparison;
- import UFO/designspace/TTF/OTF/WOFF2 where licensing and parser policy allow;
- export TTF/OTF/WOFF2 and project packages through validated adapters;
- font validation, contour repair suggestions, interpolation checks, table size/limit checks;
- license, attribution, embedding-rights and provenance metadata.

## Domain model

`FontProject` contains immutable IDs, metadata/license, Unicode/glyph map, glyph masters/layers/contours/components/anchors, global metrics, kerning groups/pairs, features, axes/instances, sources, history and validation state.

Geometry reuses GGEN's vector path model but font semantics remain separate: winding, extrema, overlaps, component transforms, interpolation point compatibility, coordinate units, and OpenType table rules are not generic illustration behavior.

## Safety and rights

- Imported fonts are untrusted and bounded by byte/table/glyph/contour/point/instruction limits.
- Opening a font does not grant modification or redistribution rights.
- Protected RGEN fonts are read/shape/embed only according to their manifest policy; destructive font tools cannot target protected IDs.
- Genuine Lucida remains distribution-blocked until license evidence exists.
- Export performs a rights/fidelity warning and never silently strips required tables/features.

## Testing

- shaping corpus for Bangla, English, Arabic, Hindi/Devanagari, Urdu and mixed bidi;
- HarfBuzz/reference glyph sequence/position comparisons;
- outline serialization and round-trip properties;
- interpolation compatibility and variable-axis tests;
- GSUB/GPOS feature compilation fixtures;
- malicious font corpus and resource limits;
- export validation with independent validators;
- visual proof goldens with pinned rasterizer versions;
- touch/stylus/mouse node-editing interaction and undo tests.

## Phasing

1. Typography/shaping/fallback inspector and safe font registry.
2. Font project schema, glyph browser, outline/metrics editor.
3. Components/anchors/kerning/features and proofing.
4. Masters/variable fonts/interpolation.
5. validated multi-format export, hinting/color-font expansion and plugin API.
