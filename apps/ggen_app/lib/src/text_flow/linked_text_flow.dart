/// App-side text-flow presentation for linked text frames (Stage 4.2).
///
/// This module sits between the platform-neutral `ggen_core` flow contracts
/// (`TextFlowEngine`, `TextFlowLinkResolver`) and the Flutter canvas: it
/// resolves the link structure of one artboard and computes, per frame, the
/// deterministic slice of the story that frame renders plus the two flow
/// indicators the canvas distinguishes:
///
///  * **continuation** — the frame is full and the story continues into the
///    next linked frame (blue right-arrow tab). Continuation is NOT an
///    overflow: the red tab is withheld from these frames.
///  * **terminal overflow** — the story continues past the LAST frame of the
///    chain (red corner tab). Occurs exactly once, on the terminal frame
///    ([TextFlowChain.terminalOverflowFrame]).
///
/// Everything here is pure and deterministic; nothing mutates the project.
/// Fail-closed: a malformed link structure (dangling reference, ambiguous
/// target, …) makes [computeLinkedTextFlow] return null and the canvas falls
/// back to the legacy per-node rendering.
library;

import 'package:flutter/material.dart';

import 'package:ggen_core/ggen_core.dart';

import '../controller/studio_controller.dart';

// ── Measurement ──────────────────────────────────────────────────────────

/// Flutter `TextPainter`-backed measurement for the core text-flow engine.
///
/// Core stays rendering-free; the shell supplies this provider so multi-column
/// layout uses real platform typography (wrapping, line height) rather than
/// the monospace stub. Stateless: a [TextPainter] is created per call because
/// measurement happens during build/layout, not on a retained painter.
class FlutterTextMeasurement implements TextMeasurementProvider {
  const FlutterTextMeasurement();

  TextSpan _span(String text, double fontSize) =>
      TextSpan(text: text, style: TextStyle(fontSize: fontSize, height: 1.2));

  @override
  int charactersThatFit({
    required String text,
    required int start,
    required double maxWidth,
    required double fontSize,
  }) {
    if (maxWidth <= 0 || fontSize <= 0 || start >= text.length) return 0;
    final painter = TextPainter(
      text: _span('', fontSize),
      textDirection: TextDirection.ltr,
    );
    // Binary search for the largest prefix that paints within maxWidth.
    var lo = 0;
    var hi = text.length - start;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      painter.text = _span(text.substring(start, start + mid), fontSize);
      painter.layout(maxWidth: double.infinity);
      if (painter.width <= maxWidth) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    painter.dispose();
    return lo;
  }

  @override
  double measureTextHeight({
    required String text,
    required double maxWidth,
    required double fontSize,
  }) {
    if (text.isEmpty || maxWidth <= 0 || fontSize <= 0) return 0;
    final painter = TextPainter(
      text: _span(text, fontSize),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  double lineHeight(double fontSize) {
    final painter = TextPainter(
      text: _span('Mg', fontSize),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    final value = painter.preferredLineHeight;
    painter.dispose();
    return value;
  }
}

/// Default shell measurement provider for text flow.
const TextMeasurementProvider kDefaultTextMeasurement =
    FlutterTextMeasurement();

/// Computes the multi-column flow result for a frame text node, or null when
/// the node lacks frame geometry or a valid text payload. Presentation code
/// uses this to render column widgets and guides; it never mutates the node.
TextFlowResult? flowTextFrame(
  DocumentNode node, {
  TextMeasurementProvider measurement = kDefaultTextMeasurement,
}) {
  final geom = textNodeFrameGeometry(node);
  if (geom == null) return null;
  final layout = textNodeColumnLayout(node);
  final text = node.extensions['text'];
  final size = node.extensions['size'];
  if (text is! String || size is! num) return null;
  final engine = TextFlowEngine(measurement);
  return engine.flow(
    story: text,
    frames: [
      TextFlowFrameInput(
        frameId: node.id.value,
        geometry: geom,
        layout: layout,
      ),
    ],
    fontSize: size.toDouble(),
  );
}

// ── Per-frame flow state ─────────────────────────────────────────────────

/// One frame's place in the linked flow of an artboard.
final class TextFrameFlow {
  const TextFrameFlow({
    required this.result,
    required this.chainLength,
    required this.continuation,
    required this.terminalOverflow,
    this.successorId,
  });

  /// The engine's per-frame result: the exact column slices this frame
  /// renders (never the whole story).
  final TextFlowFrameResult result;

  /// Number of frames in this frame's chain (1 = isolated frame).
  final int chainLength;

  /// Successor frame id within the chain, or null when this frame is the
  /// chain's last frame.
  final String? successorId;

  /// True when this frame is full and the story continues into the next
  /// linked frame. Continuation is NOT overflow: the red tab is withheld
  /// and the blue continuation indicator is shown instead.
  final bool continuation;

  /// True when the story continues past this frame and this frame is the
  /// chain's terminal frame. Happens exactly once per chain.
  final bool terminalOverflow;
}

/// The resolved, render-ready flow state of one artboard.
///
/// Every text frame that could be flowed gets a [TextFrameFlow] (including
/// isolated single-frame chains). Frames whose chain fell back (a member
/// without frame geometry/text/size) are absent: the canvas renders them
/// with the legacy standalone path.
final class LinkedTextFlow {
  LinkedTextFlow._({
    required this.links,
    required Map<String, TextFrameFlow> slices,
  }) : _slices = Map<String, TextFrameFlow>.unmodifiable(slices);

  /// The validated link structure of the artboard.
  final TextFlowLinkSet links;

  final Map<String, TextFrameFlow> _slices;

  /// Map of frame id -> per-frame flow state. Unmodifiable.
  Map<String, TextFrameFlow> get slices => _slices;

  /// The per-frame flow state for [frameId], or null when the frame has no
  /// frame payload or its chain fell back to standalone rendering.
  TextFrameFlow? sliceFor(String frameId) => _slices[frameId];
}

// ── Chain flow computation ───────────────────────────────────────────────

/// Resolves the artboard's linked text frames and computes each frame's
/// render slice through the core [TextFlowEngine].
///
/// Returns null when the link structure is malformed (any fail-closed
/// [ArgumentError] from [TextFlowLinkResolver.fromArtboard]); callers then
/// render every frame the legacy standalone way.
///
/// A multi-frame chain flows as ONE story: the concatenated `text`
/// extensions of the chain in flow order (the links-first contract — no
/// TextStory). The chain's font size is the FIRST frame's size: the engine
/// takes one size per flow call, and per-frame sizes are a documented
/// limitation of this milestone. A chain that contains a frame without a
/// valid frame geometry / text / size falls back to standalone rendering
/// for ALL of its members (no slice is produced for them).
LinkedTextFlow? computeLinkedTextFlow(
  Artboard artboard, {
  TextMeasurementProvider measurement = kDefaultTextMeasurement,
}) {
  final TextFlowLinkSet links;
  try {
    links = TextFlowLinkResolver.fromArtboard(artboard);
  } on ArgumentError {
    return null; // Malformed links: fail closed to legacy rendering.
  }
  if (links.isEmpty) {
    return LinkedTextFlow._(
      links: links,
      slices: const <String, TextFrameFlow>{},
    );
  }

  final engine = TextFlowEngine(measurement);
  final slices = <String, TextFrameFlow>{};
  for (final chain in links.chains) {
    final members = <DocumentNode>[];
    var flowable = true;
    for (final id in chain.ids) {
      final index = artboard.nodes.indexWhere((n) => n.id.value == id);
      if (index < 0) {
        flowable = false;
        break;
      }
      members.add(artboard.nodes[index]);
    }
    if (!flowable) continue;

    final inputs = <TextFlowFrameInput>[];
    final storyBuilder = StringBuffer();
    double? fontSize;
    for (final node in members) {
      final geometry = textNodeFrameGeometry(node);
      final text = node.extensions['text'];
      final size = node.extensions['size'];
      if (geometry == null ||
          text is! String ||
          size is! num ||
          !size.isFinite ||
          size <= 0) {
        flowable = false; // Legacy label-sized member: stand alone.
        break;
      }
      storyBuilder.write(text);
      inputs.add(
        TextFlowFrameInput(
          frameId: node.id.value,
          geometry: geometry,
          layout: textNodeColumnLayout(node),
        ),
      );
      // The HEAD frame's size flows the whole chain (see class docs).
      fontSize ??= size.toDouble();
    }
    if (!flowable || fontSize == null) continue;

    final story = storyBuilder.toString();
    final result = engine.flow(
      story: story,
      frames: inputs,
      fontSize: fontSize,
    );
    final terminal = chain.terminalOverflowFrame(result);
    for (var i = 0; i < chain.length; i++) {
      final frameId = chain[i];
      // The engine stops appending frames once the story is exhausted; later
      // chain frames simply receive nothing.
      final frameResult =
          i < result.frames.length
              ? result.frames[i]
              : TextFlowFrameResult(frameId: frameId, columns: const []);
      slices[frameId] = TextFrameFlow(
        result: frameResult,
        chainLength: chain.length,
        successorId: i + 1 < chain.length ? chain[i + 1] : null,
        continuation: i + 1 < chain.length && frameResult.hasOverflow,
        terminalOverflow: terminal == frameId,
      );
    }
  }
  return LinkedTextFlow._(links: links, slices: slices);
}

// ── Link candidates (UI helper) ──────────────────────────────────────────

/// Text frames in [artboard] that [sourceId] may link to right now:
/// text frames with a valid frame rectangle, not the source itself, with no
/// predecessor (an ambiguous target) and not upstream of the source in its
/// chain (a cycle).
///
/// Deterministic (artboard node order). Empty when the artboard's link
/// structure is malformed, so the UI hides the link action entirely.
List<DocumentNode> linkCandidates(Artboard artboard, GgenId sourceId) {
  final TextFlowLinkSet links;
  try {
    links = TextFlowLinkResolver.fromArtboard(artboard);
  } on ArgumentError {
    return const <DocumentNode>[];
  }
  final chain = links.chainContaining(sourceId.value);
  final position = chain == null ? -1 : chain.indexOf(sourceId.value);
  final upstream = <String>{
    if (chain != null && position > 0) ...chain.ids.sublist(0, position),
  };
  final hasPredecessor = <String>{
    for (final target in links.successors.values)
      if (target case final String t) t,
  };
  return <DocumentNode>[
    for (final node in artboard.nodes)
      if (node.kind == DocumentNodeKind.textFrame &&
          node.id != sourceId &&
          textNodeFrameGeometry(node) != null &&
          !upstream.contains(node.id.value) &&
          !hasPredecessor.contains(node.id.value))
        node,
  ];
}
