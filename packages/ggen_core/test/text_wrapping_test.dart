import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

// Monospace provider @ fontSize 10: char width 6.0, line height 14.0.
// A single-column frame of width W fits floor(W/6) chars per line; height
// 14 allows exactly one line, exposing the break decision directly.
const engine = TextFlowEngine(MonospaceMeasurementProvider());
const fontSize = 10.0;

class ColResult {
  ColResult(this.story, double width, {int lines = 1}) {
    final h = lines * 14.0;
    final result = engine.flow(
      story: story,
      frames: [
        TextFlowFrameInput(
          frameId: 'A',
          geometry: FrameGeometry(
            x: 0,
            y: 0,
            frameWidth: width,
            frameHeight: h,
          ),
          layout: ColumnLayout.single,
        ),
      ],
      fontSize: fontSize,
    );
    this.result = result;
    visible = result.frames.single.columns.single.visibleText;
    overflow = story.substring(result.consumed);
  }

  final String story;
  late final TextFlowResult result;
  late final String visible;
  late final String overflow;

  void expectConservation() =>
      expect(result.conserves(story), isTrue, reason: 'conservation');
}

void main() {
  group('Word-boundary wrapping (width cut with a fitting boundary)', () {
    test('breaks at the last word boundary that fits, not mid-word', () {
      // 48 wide -> 8 chars/line. "hello world": naive cut "hello wo",
      // policy breaks after "hello ".
      final r = ColResult('hello world', 48);
      expect(r.visible, 'hello ');
      expect(r.overflow, 'world');
      r.expectConservation();
    });

    test('a cut landing exactly on whitespace keeps the boundary', () {
      // 42 wide -> 7 chars/line. "hello  world": cut position is a space.
      final r = ColResult('hello  world', 42);
      expect(r.visible, 'hello  ');
      expect(r.overflow, 'world');
      r.expectConservation();
    });

    test('multiple spaces: the whole run is trailing line whitespace', () {
      // 48 wide -> 8 chars/line. "hello    world" (4 spaces): the cut
      // lands inside the run; the entire run is consumed with the line.
      final r = ColResult('hello    world', 48);
      expect(r.visible, 'hello    ');
      expect(r.overflow, 'world');
      r.expectConservation();
    });

    test('word exactly filling the line breaks before the following word', () {
      // 36 wide -> 6 chars/line. "abcd ef": cut "abcd e" breaks at the
      // boundary -> "abcd ".
      final r = ColResult('abcd ef', 36);
      expect(r.visible, 'abcd ');
      expect(r.overflow, 'ef');
      r.expectConservation();
    });

    test('tab is breakable whitespace', () {
      // 42 wide -> 7 chars/line. "ab\tcd ef": cut "ab\tcd e" breaks after
      // the space -> "ab\tcd ".
      final r = ColResult('ab\tcd ef', 42);
      expect(r.visible, 'ab\tcd ');
      expect(r.overflow, 'ef');
      r.expectConservation();
    });

    test('wrapped line never starts with whitespace (2 lines)', () {
      // 48 wide, 2 lines. "hello world" wraps: line1 "hello ", line2
      // "world" — the second line starts with the word, not a space.
      final r = ColResult('hello world', 48, lines: 2);
      expect(r.visible, 'hello world');
      expect(r.overflow, '');
      r.expectConservation();
    });
  });

  group('Long unbreakable tokens (character split fallback)', () {
    test('token longer than the line is split at the exact fit count', () {
      // 42 wide -> 7 chars/line; no whitespace at all.
      final r = ColResult('abcdefghij', 42);
      expect(r.visible, 'abcdefg');
      expect(r.overflow, 'hij');
      r.expectConservation();
    });

    test('token exceeding the line, followed by a word', () {
      // 48 wide -> 8 chars/line. "hellooooo world" (token = 9 chars):
      // no boundary in the first 8 -> character split at 8.
      final r = ColResult('hellooooo world', 48);
      expect(r.visible, 'helloooo');
      expect(r.overflow, 'o world');
      r.expectConservation();
    });
  });

  group('Whitespace semantics (never collapsed or dropped)', () {
    test('whitespace-only line that does not fit consumes the whole run', () {
      // 36 wide -> 6 chars/line; 8 spaces: the maximal whitespace prefix
      // (8) is consumed as the indent-only line.
      final r = ColResult('        ', 36);
      expect(r.visible, '        ');
      expect(r.overflow, '');
      r.expectConservation();
    });

    test('whitespace-only segment that fits is consumed with its newline', () {
      final r = ColResult('    \n', 48, lines: 2);
      expect(r.visible, '    \n');
      expect(r.overflow, '');
      r.expectConservation();
    });

    test('leading whitespace after a hard break is preserved in order', () {
      // 42 wide -> 7 chars/line, 2 lines. "abc\n   indented":
      // line1 "abc\n", line2 character-splits at 7 -> "   inde".
      final r = ColResult('abc\n   indented', 42, lines: 2);
      expect(r.visible, 'abc\n   inde');
      expect(r.overflow, 'nted');
      r.expectConservation();
    });
  });

  group('Hard-break (newline) semantics', () {
    test('trailing newline is an explicit empty line, never dropped', () {
      final r = ColResult('abc\n', 48, lines: 2);
      expect(r.visible, 'abc\n');
      expect(r.overflow, '');
      r.expectConservation();
    });

    test('consecutive newlines render as explicit empty lines', () {
      // 3 lines available: "abc\n", empty line for the second \n.
      final r = ColResult('abc\n\n', 48, lines: 3);
      expect(r.visible, 'abc\n\n');
      expect(r.overflow, '');
      r.expectConservation();
    });

    test('mixed newline/width wrapping', () {
      // 36 wide -> 6 chars/line, 3 lines. "line one line two\nfinal":
      // line1 "line ", line2 "one ", line3 "line " -> 14 consumed.
      final r = ColResult('line one line two\nfinal', 36, lines: 3);
      expect(r.visible, 'line one line ');
      expect(r.overflow, 'two\nfinal');
      r.expectConservation();
    });
  });

  group('Degenerate and preserved edge behavior', () {
    test('not even one char fits: forced one-char progress (preserved)', () {
      // 3 wide -> 0 chars/line. Old behavior preserved: one char per line.
      final r = ColResult('ab', 3);
      expect(r.visible, 'a');
      expect(r.overflow, 'b');
      r.expectConservation();
    });

    test('short text fitting fully is untouched', () {
      final r = ColResult('short', 300);
      expect(r.visible, 'short');
      expect(r.overflow, '');
      r.expectConservation();
    });
  });
}
