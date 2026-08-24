import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_app/src/text_flow/linked_text_flow.dart';
import 'package:ggen_core/ggen_core.dart';

/// Deterministic test provider (core monospace stub): 0.6 * fontSize per
/// character, 1.4 * fontSize per line — the same provider CI uses.
const TextMeasurementProvider _m = MonospaceMeasurementProvider();

DocumentNode frame(
  String id, {
  String text = 'A',
  double size = 10,
  double w = 100,
  double h = 100,
  double x = 0,
  double y = 0,
  int columns = 1,
  double gutter = 0,
  String? next,
  bool withRect = true,
}) => DocumentNode(
  id: GgenId(id),
  kind: DocumentNodeKind.textFrame,
  name: id,
  extensions: <String, Object?>{
    'x': x,
    'y': y,
    if (withRect) 'w': w,
    if (withRect) 'h': h,
    'size': size,
    'text': text,
    'color': 0xFF000000,
    'columns': columns,
    'gutter': gutter,
    if (next != null) textFrameNextFrameExtension: next,
  },
);

Artboard artboard(List<DocumentNode> nodes) => Artboard(
  id: GgenId('ab'),
  name: 'A',
  width: 1080,
  height: 1920,
  nodes: nodes,
);

void main() {
  group('computeLinkedTextFlow', () {
    test('isolated frames each get a single-frame slice', () {
      final a = frame('a', text: 'hello');
      final b = frame('b', text: 'world', x: 200);
      final flow =
          computeLinkedTextFlow(
            artboard(<DocumentNode>[a, b]),
            measurement: _m,
          )!;
      expect(flow.links.chains, hasLength(2));
      final sa = flow.sliceFor('a')!;
      final sb = flow.sliceFor('b')!;
      expect(sa.chainLength, 1);
      expect(sb.chainLength, 1);
      expect(sa.continuation, isFalse);
      expect(sa.terminalOverflow, isFalse);
      expect(sa.result.columns.map((c) => c.visibleText).join(), 'hello');
      expect(sb.result.columns.map((c) => c.visibleText).join(), 'world');
    });

    test('linked frames flow one story; each frame renders its own slice', () {
      // Monospace @10: 6.0u/char, 14.0u/line. 100x100 frame => 16 chars/
      // line, floor(100/14) = 7 lines => capacity 112 per frame.
      final a = frame('a', text: 'a' * 200, next: 'b');
      final b = frame('b', text: 'BB', x: 200);
      final flow =
          computeLinkedTextFlow(
            artboard(<DocumentNode>[a, b]),
            measurement: _m,
          )!;

      final story = 'a' * 200 + 'BB';
      final sa = flow.sliceFor('a')!;
      final sb = flow.sliceFor('b')!;
      expect(sa.chainLength, 2);
      expect(sa.successorId, 'b');
      expect(sa.continuation, isTrue); // frame full, story continues
      expect(sa.terminalOverflow, isFalse);

      expect(sb.chainLength, 2);
      expect(sb.successorId, isNull);
      expect(sb.continuation, isFalse);
      expect(sb.terminalOverflow, isFalse); // everything fit

      expect(sa.result.columns.map((c) => c.visibleText).join(), 'a' * 112);
      expect(
        sb.result.columns.map((c) => c.visibleText).join(),
        'a' * 88 + 'BB',
      );

      // No duplication: the whole story appears exactly once across frames.
      final rendered =
          [
            ...flow.slices.values.map(
              (s) => s.result.columns.map((c) => c.visibleText).join(),
            ),
          ].join();
      expect(rendered, story);
    });

    test('terminal overflow is reported exactly once, on the last frame', () {
      final a = frame('a', text: 'a' * 200, next: 'b');
      final b = frame('b', text: 'b' * 200, x: 200);
      final flow =
          computeLinkedTextFlow(
            artboard(<DocumentNode>[a, b]),
            measurement: _m,
          )!;

      final sa = flow.sliceFor('a')!;
      final sb = flow.sliceFor('b')!;
      expect(sa.continuation, isTrue);
      expect(sa.terminalOverflow, isFalse);
      expect(sb.continuation, isFalse);
      expect(sb.terminalOverflow, isTrue);
    });

    test('story exhausted mid-chain leaves later frames empty', () {
      final a = frame('a', text: 'abc', next: 'b');
      final b = frame('b', text: '', x: 200);
      final flow =
          computeLinkedTextFlow(
            artboard(<DocumentNode>[a, b]),
            measurement: _m,
          )!;
      final sa = flow.sliceFor('a')!;
      final sb = flow.sliceFor('b')!;
      expect(sa.result.columns.map((c) => c.visibleText).join(), 'abc');
      expect(sa.continuation, isFalse);
      expect(sb.continuation, isFalse);
      expect(sb.terminalOverflow, isFalse);
      expect(sb.result.columns.map((c) => c.visibleText).join(), isEmpty);
    });

    test('conservation holds across the chain', () {
      final a = frame('a', text: 'word ' * 30, next: 'b');
      final b = frame('b', text: 'tail', x: 200);
      final flow =
          computeLinkedTextFlow(
            artboard(<DocumentNode>[a, b]),
            measurement: _m,
          )!;
      final story = 'word ' * 30 + 'tail';
      final engine = TextFlowEngine(_m);
      final expected = engine.flow(
        story: story,
        frames: <TextFlowFrameInput>[
          TextFlowFrameInput(
            frameId: 'a',
            geometry: textNodeFrameGeometry(a)!,
            layout: textNodeColumnLayout(a),
          ),
          TextFlowFrameInput(
            frameId: 'b',
            geometry: textNodeFrameGeometry(b)!,
            layout: textNodeColumnLayout(b),
          ),
        ],
        fontSize: 10,
      );
      expect(expected.conserves(story), isTrue);
      final rendered =
          [
            for (final s in flow.slices.values)
              s.result.columns.map((c) => c.visibleText).join(),
          ].join();
      expect(rendered, story.substring(0, expected.consumed));
    });

    test('chain falls back to standalone when a member lacks a frame rect', () {
      final a = frame('a', text: 'hello', next: 'b');
      final b = frame('b', text: 'world', x: 200, withRect: false);
      final flow =
          computeLinkedTextFlow(
            artboard(<DocumentNode>[a, b]),
            measurement: _m,
          )!;
      // Malformed-for-flow chain: NO slices for either member; the canvas
      // renders both through the legacy standalone path.
      expect(flow.sliceFor('a'), isNull);
      expect(flow.sliceFor('b'), isNull);
      expect(flow.slices, isEmpty);
    });

    test('malformed links (dangling target) return null', () {
      final a = frame('a', text: 'hello', next: 'ghost');
      final flow = computeLinkedTextFlow(
        artboard(<DocumentNode>[a]),
        measurement: _m,
      );
      expect(flow, isNull);
    });

    test('non-string nextFrame value returns null', () {
      final a = frame('a', text: 'hello', next: '42');
      final n = DocumentNode(
        id: a.id,
        kind: a.kind,
        name: a.name,
        extensions: <String, Object?>{
          ...a.extensions,
          textFrameNextFrameExtension: 42,
        },
      );
      expect(
        computeLinkedTextFlow(artboard(<DocumentNode>[n]), measurement: _m),
        isNull,
      );
    });

    test('non-text node declaring nextFrame returns null', () {
      final shape = DocumentNode(
        id: GgenId('shape'),
        kind: DocumentNodeKind.shape,
        name: 'S',
        extensions: <String, Object?>{
          'x': 0,
          'y': 0,
          'w': 64,
          'h': 64,
          'color': 0xFF112233,
          textFrameNextFrameExtension: 'a',
        },
      );
      final a = frame('a', text: 'hello');
      expect(
        computeLinkedTextFlow(
          artboard(<DocumentNode>[shape, a]),
          measurement: _m,
        ),
        isNull,
      );
    });

    test('legacy documents without link metadata resolve unchanged', () {
      final a = frame('a', text: 'legacy');
      final b = frame('b', text: 'and more', x: 200);
      final flow =
          computeLinkedTextFlow(
            artboard(<DocumentNode>[a, b]),
            measurement: _m,
          )!;
      expect(flow.links.chains, hasLength(2));
      expect(flow.sliceFor('a')!.chainLength, 1);
      expect(flow.sliceFor('b')!.chainLength, 1);
    });
  });

  group('linkCandidates', () {
    test('excludes predecessors, upstream frames and legacy frames', () {
      final a = frame('a', text: 'A');
      final b = frame('b', text: 'B', x: 150, next: 'c');
      final c = frame('c', text: 'C', x: 300);
      final d = frame('d', text: 'D', x: 450, withRect: false);
      final art = artboard(<DocumentNode>[a, b, c, d]);

      // A is isolated: its only candidate is B. C already has predecessor B
      // (an A -> C link would be ambiguous) and D has no frame rect.
      expect(linkCandidates(art, a.id).map((n) => n.id.value), <String>['b']);

      // B heads the B -> C chain: re-linking B -> A would replace its
      // successor (A has no predecessor and is not upstream of B). C is
      // excluded (already the successor / ambiguous).
      expect(linkCandidates(art, b.id).map((n) => n.id.value), <String>['a']);

      // C is terminal: C -> A is valid, but C -> B would close the cycle
      // B -> C -> B (B is upstream of C) and C -> D is not linkable (D has
      // no frame rect).
      expect(linkCandidates(art, c.id).map((n) => n.id.value), <String>['a']);
    });

    test('malformed artboard links yield no candidates', () {
      final a = frame('a', text: 'A', next: 'ghost');
      expect(linkCandidates(artboard(<DocumentNode>[a]), a.id), isEmpty);
    });
  });

  group('page-aware placement', () {
    test('artboardAsPage exposes the artboard as a zero-margin page', () {
      final art = artboard(<DocumentNode>[]);
      final page = artboardAsPage(art);
      expect(page.margins, PageMargins.zero);
      expect(page.bleed, PageBleed.none);
      expect(page.contentBounds.left, 0);
      expect(page.contentBounds.top, 0);
      expect(page.contentBounds.right, 1080);
      expect(page.contentBounds.bottom, 1920);
    });

    test('clampFrameIntoPage keeps the whole frame inside the page', () {
      final art = artboard(<DocumentNode>[]);
      // In-bounds tap: unchanged.
      expect(clampFrameIntoPage(art, 100, 120, 480, 360), (100.0, 120.0));
      // Far outside: clamps to the content top-left.
      expect(clampFrameIntoPage(art, -500, -500, 480, 360), (0.0, 0.0));
      // Past the far edge: frame still fits entirely inside.
      expect(clampFrameIntoPage(art, 2000, 5000, 480, 360), (
        1080.0 - 480.0,
        1920.0 - 360.0,
      ));
      // Degenerate: frame at least as large as the page anchors top-left.
      expect(clampFrameIntoPage(art, 50, 60, 2000, 4000), (0.0, 0.0));
    });
  });

  group('flowTextFrame (regression)', () {
    test('returns null for legacy label-sized nodes', () {
      final legacy = frame('a', text: 'hello', withRect: false);
      expect(flowTextFrame(legacy, measurement: _m), isNull);
    });

    test('flows a standalone frame through the engine', () {
      final a = frame('a', text: 'x' * 200);
      final result = flowTextFrame(a, measurement: _m)!;
      expect(result.conserves('x' * 200), isTrue);
      expect(result.hasOverflow, isTrue);
    });
  });
}
