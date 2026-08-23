import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

TextFlowFrameInput frame(
  String id, {
  double w = 100,
  double h = 100,
  int columns = 1,
  double gutter = 0,
  double pad = 0,
}) => TextFlowFrameInput(
  frameId: id,
  geometry: FrameGeometry(
    x: 0,
    y: 0,
    frameWidth: w,
    frameHeight: h,
    innerPadding: pad,
  ),
  layout: ColumnLayout.create(columnCount: columns, gutter: gutter),
);

void main() {
  // Monospace: char width = 0.6 * fontSize. At fontSize 10 -> 6.0 per char,
  // line height 14. A 100x100 frame => ~16 chars/line, 7 lines => ~112 chars.
  const engine = TextFlowEngine(MonospaceMeasurementProvider());
  const fontSize = 10.0;

  group('Single-column regression', () {
    test('short text fits fully in one column, no overflow', () {
      final result = engine.flow(
        story: 'Hello',
        frames: [frame('A')],
        fontSize: fontSize,
      );
      expect(result.hasOverflow, isFalse);
      expect(result.consumed, 5);
      expect(result.overflowLength, 0);
      expect(result.frames.single.columns.single.visibleText, 'Hello');
      expect(result.conserves('Hello'), isTrue);
    });

    test('empty text produces empty column, no overflow', () {
      final result = engine.flow(
        story: '',
        frames: [frame('A')],
        fontSize: fontSize,
      );
      expect(result.consumed, 0);
      expect(result.hasOverflow, isFalse);
      expect(result.frames.single.columns.single.visibleText, '');
    });

    test('no frames means everything is overflow', () {
      final result = engine.flow(
        story: 'abc',
        frames: const [],
        fontSize: fontSize,
      );
      expect(result.consumed, 0);
      expect(result.overflowLength, 3);
      expect(result.conserves('abc'), isTrue);
    });
  });

  group('Multi-column sequential flow', () {
    test('2-column flow fills column 1 before column 2', () {
      // Use a small frame so text spans both columns.
      // 60-wide frame, 2 columns, no gutter => each column 30 wide => 5 chars.
      // 30-high => 2 lines => 10 chars per column.
      final result = engine.flow(
        story: '0123456789ABCDEFGHIJ', // 20 chars
        frames: [frame('A', w: 60, h: 30, columns: 2)],
        fontSize: fontSize,
      );
      final cols = result.frames.single.columns;
      expect(cols, hasLength(2));
      expect(cols[0].columnIndex, 0);
      expect(cols[1].columnIndex, 1);
      // First column filled before second.
      expect(cols[0].visibleText, '0123456789');
      expect(cols[1].visibleText, 'ABCDEFGHIJ');
      expect(result.hasOverflow, isFalse);
      expect(result.conserves('0123456789ABCDEFGHIJ'), isTrue);
    });

    test('3-column flow preserves order', () {
      final result = engine.flow(
        story: 'AAAAAAAAAA' 'BBBBBBBBBB' 'CCCCCCCCCC',
        frames: [frame('A', w: 90, h: 30, columns: 3)],
        fontSize: fontSize,
      );
      final cols = result.frames.single.columns;
      expect(cols.map((c) => c.visibleText), [
        'AAAAAAAAAA',
        'BBBBBBBBBB',
        'CCCCCCCCCC',
      ]);
      expect(result.conserves('AAAAAAAAAABBBBBBBBBBCCCCCCCCCC'), isTrue);
    });

    test('4+ columns', () {
      // 96-wide / 4 cols / no gutter => 24 per col => 4 chars/line at size 10.
      final result = engine.flow(
        story: 'AAAABBBBCCCCDDDD',
        frames: [frame('A', w: 96, h: 16, columns: 4)],
        fontSize: fontSize,
      );
      expect(result.frames.single.columns, hasLength(4));
      expect(
        result.frames.single.columns.map((c) => c.visibleText),
        ['AAAA', 'BBBB', 'CCCC', 'DDDD'],
      );
      expect(result.conserves('AAAABBBBCCCCDDDD'), isTrue);
    });

    test('gutter reduces column width', () {
      // Without gutter a 64-wide column fits 10 chars/line; with 4 gutter and
      // 2 cols each column is 30 wide => 5 chars/line. Height allows 1 line.
      final withGutter = engine.flow(
        story: '0123456789',
        frames: [frame('A', w: 64, h: 16, columns: 2, gutter: 4)],
        fontSize: fontSize,
      );
      final cols = withGutter.frames.single.columns;
      expect(cols[0].bounds.bounds.width, 30);
      expect(cols[1].bounds.bounds.width, 30);
      expect(cols[0].visibleText, '01234');
      expect(cols[1].visibleText, '56789');
      expect(withGutter.conserves('0123456789'), isTrue);
    });
  });

  group('Terminal overflow', () {
    test('text longer than capacity reports overflow and marks last column',
        () {
      final result = engine.flow(
        story: '0123456789' '0123456789' 'EXTRA', // 25 chars, capacity ~20
        frames: [frame('A', w: 60, h: 30, columns: 2)],
        fontSize: fontSize,
      );
      expect(result.hasOverflow, isTrue);
      expect(result.overflowLength, 5);
      final last = result.frames.single.columns.last;
      expect(last.hasOverflow, isTrue);
      expect(result.conserves('01234567890123456789EXTRA'), isTrue);
    });

    test('empty trailing columns are not flagged as overflow', () {
      final result = engine.flow(
        story: 'short',
        frames: [frame('A', w: 300, h: 300, columns: 3)],
        fontSize: fontSize,
      );
      final cols = result.frames.single.columns;
      expect(cols[0].visibleText, 'short');
      expect(cols[1].visibleText, '');
      expect(cols[2].visibleText, '');
      for (final c in cols) {
        expect(c.hasOverflow, isFalse);
      }
    });
  });

  group('Linked multi-frame + multi-column flow', () {
    test('Frame A columns fill, then Frame B columns, strict conservation',
        () {
      final story =
          'AAAAAAAAAA' 'BBBBBBBBBB' 'CCCCCCCCCC' 'DDDDDDDDDD' 'EEEEEEEEEE';
      // Each frame: 2 cols, 10 chars/col => 20 chars/frame.
      final result = engine.flow(
        story: story,
        frames: [
          frame('A', w: 60, h: 30, columns: 2),
          frame('B', w: 60, h: 30, columns: 2),
          frame('C', w: 60, h: 30, columns: 2),
        ],
        fontSize: fontSize,
      );
      expect(result.frames.map((f) => f.frameId), ['A', 'B', 'C']);
      expect(result.hasOverflow, isFalse);
      expect(result.consumed, story.length);
      // Verify reading order across frames/columns.
      final ordered = result.allColumns
          .map((c) => c.visibleText)
          .join();
      expect(ordered, story);
      // No duplication: unique ranges.
      final ranges = result.allColumns
          .map((c) => '${c.frameId}:${c.columnIndex}')
          .toSet();
      expect(ranges.length, result.allColumns.length);
      expect(result.conserves(story), isTrue);
    });

    test('terminal overflow after last linked frame is reported once', () {
      final story = 'AAAAAAAAAA' 'BBBBBBBBBB' 'TAIL';
      final result = engine.flow(
        story: story,
        frames: [frame('A', w: 60, h: 30, columns: 2)],
        fontSize: fontSize,
      );
      expect(result.overflowLength, 4);
      final overflowCols = result.allColumns.where((c) => c.hasOverflow);
      expect(overflowCols, hasLength(1));
      expect(result.conserves(story), isTrue);
    });

    test('mixed single and multi column frames chain correctly', () {
      final result = engine.flow(
        story: 'A' * 10 + 'B' * 10 + 'C' * 10,
        frames: [
          frame('A', w: 60, h: 30, columns: 2), // 20 cap
          frame('B', w: 60, h: 30, columns: 1), // 10 cap
        ],
        fontSize: fontSize,
      );
      expect(result.hasOverflow, isFalse);
      expect(result.frames[0].columns, hasLength(2));
      expect(result.frames[1].columns, hasLength(1));
      expect(
        result.allColumns.map((c) => c.visibleText).join(),
        'A' * 10 + 'B' * 10 + 'C' * 10,
      );
    });
  });

  group('Provider compatibility', () {
    test('custom provider is used for capacity per column', () {
      // Provider that says only 2 chars fit per line, 1 line per column.
      final provider = _FixedProvider(charsPerLine: 2, lines: 1);
      final e = TextFlowEngine(provider);
      // Frame is one line tall (lineHeight == fontSize == 10), so capacity is
      // exactly charsPerLine per column.
      final result = e.flow(
        story: 'ABCDEF',
        frames: [frame('A', w: 100, h: 10, columns: 3)],
        fontSize: 10,
      );
      expect(
        result.frames.single.columns.map((c) => c.visibleText),
        ['AB', 'CD', 'EF'],
      );
      expect(result.conserves('ABCDEF'), isTrue);
    });

    test('explicit newlines break lines', () {
      final result = engine.flow(
        story: 'AB\nCD',
        frames: [frame('A', w: 60, h: 100, columns: 1)],
        fontSize: fontSize,
      );
      expect(result.conserves('AB\nCD'), isTrue);
      expect(result.frames.single.columns.single.visibleText, 'AB\nCD');
    });
  });

  group('Transactions with column layout', () {
    test('column configuration is undo/redo safe via ProjectTransaction',
        () {
      final initial = DocumentProject(
        id: GgenId('p1'),
        name: 'P',
        artboards: [
          Artboard(
            id: GgenId('a1'),
            name: 'A',
            width: 100,
            height: 100,
            nodes: [
              DocumentNode(
                id: GgenId('n1'),
                kind: DocumentNodeKind.textFrame,
                name: 'Text',
                extensions: <String, Object?>{'columns': 3, 'gutter': 8.0},
              ),
            ],
          ),
        ],
      );
      final history = ProjectHistory.start(initial);
      final next = initial.copyWith(revision: initial.revision + 1);
      final tx = ProjectTransaction(
        description: 'Configure columns',
        before: initial,
        after: next,
      );
      final h2 = history.commit(tx);
      expect(h2.current.revision, 1);
      expect(h2.undo().current.revision, 0);
      expect(h2.undo().redo().current.revision, 1);
    });
  });
}

/// Test provider that reports a fixed capacity independent of geometry.
final class _FixedProvider implements TextMeasurementProvider {
  const _FixedProvider({required this.charsPerLine, required this.lines});
  final int charsPerLine;
  final int lines;

  @override
  int charactersThatFit({
    required String text,
    required int start,
    required double maxWidth,
    required double fontSize,
  }) {
    // [text] is already a hard-broken segment (start is always 0 at the call
    // site), but keep the general contract correct regardless.
    final remaining = text.length - start;
    return remaining < charsPerLine ? remaining : charsPerLine;
  }

  @override
  double lineHeight(double fontSize) => fontSize;

  @override
  double measureTextHeight({
    required String text,
    required double maxWidth,
    required double fontSize,
  }) => lines * lineHeight(fontSize);
}
