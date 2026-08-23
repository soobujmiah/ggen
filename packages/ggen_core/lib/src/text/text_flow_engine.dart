import 'column_layout.dart';
import 'frame_geometry.dart';

/// Platform-neutral text measurement.
///
/// GGEN core must not import Flutter (`TextPainter`) or any shaping engine.
/// Flow layout instead asks a [TextMeasurementProvider] how many characters
/// of a given source string fit in a fixed-width column at a particular font
/// size, and how tall a given slice renders. The concrete provider is
/// supplied by the shell (or tests), so the same engine works with a
/// monospace stub, a real Flutter `TextPainter`, or a future HarfBuzz-class
/// shaper without changing core.
///
/// Implementations MUST be deterministic: identical inputs return identical
/// results. They MUST report measured widths/heights in the same units as the
/// frame geometry (artboard units).
abstract interface class TextMeasurementProvider {
  /// Returns the maximum number of code units from [text] (starting at
  /// [start]) that fit within [maxWidth] at [fontSize].
  ///
  /// The returned count is in [String] code units to match Dart's UTF-16
  /// string model. It must satisfy `0 <= count <= text.length - start`.
  /// The engine treats a returned count of 0 for a non-empty slice as "not
  /// even one character fits" (degenerate narrow column) and stops filling
  /// that column rather than looping forever.
  int charactersThatFit({
    required String text,
    required int start,
    required double maxWidth,
    required double fontSize,
  });

  /// Returns the rendered height of the [text] slice when wrapped to
  /// [maxWidth] at [fontSize]. Used to decide when a column's vertical
  /// capacity is exhausted.
  double measureTextHeight({
    required String text,
    required double maxWidth,
    required double fontSize,
  });

  /// Returns the line height for [fontSize] (ascent + descent + leading).
  /// The engine uses this to derive vertical character capacity when a
  /// provider does not wrap incrementally.
  double lineHeight(double fontSize);
}

/// A simple deterministic monospace measurement provider.
///
/// Each character is [charAspect] × [fontSize] wide (default 0.6, matching the
/// shell's historical approximation) and each line is [lineHeightFactor] ×
/// [fontSize] tall. This is the CI/test provider and the default for core
/// logic; it is NOT a claim of real-device typography. The shell can swap in a
/// `TextPainter`-backed provider without core changes.
final class MonospaceMeasurementProvider implements TextMeasurementProvider {
  const MonospaceMeasurementProvider({
    this.charAspect = 0.6,
    this.lineHeightFactor = 1.4,
  });

  /// Width of one character as a fraction of font size.
  final double charAspect;

  /// Line height as a fraction of font size.
  final double lineHeightFactor;

  @override
  int charactersThatFit({
    required String text,
    required int start,
    required double maxWidth,
    required double fontSize,
  }) {
    if (start < 0 || start > text.length) {
      throw RangeError.range(start, 0, text.length, 'start');
    }
    if (maxWidth <= 0 || fontSize <= 0) return 0;
    final charWidth = charAspect * fontSize;
    if (charWidth <= 0) return 0;
    final capacity = (maxWidth / charWidth).floor();
    if (capacity <= 0) return 0;
    final remaining = text.length - start;
    return remaining < capacity ? remaining : capacity;
  }

  @override
  double measureTextHeight({
    required String text,
    required double maxWidth,
    required double fontSize,
  }) {
    if (text.isEmpty || maxWidth <= 0 || fontSize <= 0) return 0;
    final charWidth = charAspect * fontSize;
    final charsPerLine = (maxWidth / charWidth).floor();
    if (charsPerLine <= 0) return lineHeight(fontSize);
    // A trailing newline forces an extra line.
    final newlineCount = '\n'.allMatches(text).length;
    final visualLines = (text.length / charsPerLine).ceil();
    return (visualLines + newlineCount) * lineHeight(fontSize);
  }

  @override
  double lineHeight(double fontSize) => fontSize * lineHeightFactor;
}

/// One column's contribution to a text-flow result.
///
/// [visibleStart]/[visibleEnd] are code-unit offsets into the frame's source
/// text (half-open range). [visibleText] is the exact slice. [hasOverflow] is
/// true when the source did not fully fit by the end of this column; for the
/// last column of the last frame it indicates terminal overflow.
final class TextFlowColumnResult {
  const TextFlowColumnResult({
    required this.frameId,
    required this.columnIndex,
    required this.bounds,
    required this.visibleStart,
    required this.visibleEnd,
    required this.visibleText,
    required this.hasOverflow,
  });

  final String frameId;
  final int columnIndex;
  final ColumnBounds bounds;
  final int visibleStart;
  final int visibleEnd;
  final String visibleText;
  final bool hasOverflow;

  @override
  String toString() =>
      'TextFlowColumnResult($frameId col $columnIndex '
      '[$visibleStart,$visibleEnd) overflow=$hasOverflow)';
}

/// One frame's contribution to a text-flow result.
final class TextFlowFrameResult {
  const TextFlowFrameResult({
    required this.frameId,
    required this.columns,
  });

  final String frameId;
  final List<TextFlowColumnResult> columns;

  bool get hasOverflow => columns.isNotEmpty && columns.last.hasOverflow;
}

/// Input frame for the flow engine: id, geometry, column layout and the
/// (mutable) slice of the story it should start filling from.
final class TextFlowFrameInput {
  const TextFlowFrameInput({
    required this.frameId,
    required this.geometry,
    required this.layout,
  });

  final String frameId;
  final FrameGeometry geometry;
  final ColumnLayout layout;
}

/// Full flow result across one or more linked frames.
final class TextFlowResult {
  const TextFlowResult({
    required this.frames,
    required this.storyLength,
    required this.consumed,
    required this.overflowLength,
  });

  final List<TextFlowFrameResult> frames;

  /// Total code units in the source story.
  final int storyLength;

  /// Code units placed into columns across all frames.
  final int consumed;

  /// Code units that did not fit (terminal overflow).
  final int overflowLength;

  /// All column results in reading order across frames.
  Iterable<TextFlowColumnResult> get allColumns =>
      frames.expand((f) => f.columns);

  bool get hasOverflow => overflowLength > 0;

  /// Strict conservation check: consumed + overflow == storyLength, and the
  /// concatenated visible slices equal the original story prefix with no
  /// duplication or reordering.
  bool conserves(String story) {
    if (consumed + overflowLength != story.length) return false;
    final buffer = StringBuffer();
    for (final col in allColumns) {
      buffer.write(col.visibleText);
    }
    final rendered = buffer.toString();
    if (rendered.length != consumed) return false;
    return rendered == story.substring(0, consumed);
  }
}

/// Deterministic sequential text-flow engine.
///
/// Fills columns left-to-right, top-to-bottom within a frame, then proceeds
/// to the next linked frame. There is no automatic balancing. The engine is
/// pure: it never mutates its inputs and depends only on an injected
/// [TextMeasurementProvider].
final class TextFlowEngine {
  const TextFlowEngine(this.measurement);

  final TextMeasurementProvider measurement;

  /// Flows [story] across [frames] in order at [fontSize].
  TextFlowResult flow({
    required String story,
    required List<TextFlowFrameInput> frames,
    required double fontSize,
  }) {
    if (!fontSize.isFinite || fontSize <= 0) {
      throw ArgumentError('fontSize must be finite and positive.');
    }
    if (frames.isEmpty) {
      return TextFlowResult(
        frames: const [],
        storyLength: story.length,
        consumed: 0,
        overflowLength: story.length,
      );
    }

    var cursor = 0;
    final frameResults = <TextFlowFrameResult>[];

    for (final frame in frames) {
      final content = frame.geometry.contentRect;
      final geometry = ColumnGeometry.layout(
        layout: frame.layout,
        content: content,
      );

      final columns = <TextFlowColumnResult>[];
      for (var ci = 0; ci < geometry.columnCount; ci++) {
        final bounds = geometry[ci];
        final start = cursor;
        if (cursor >= story.length) {
          // Story exhausted: remaining (empty) columns carry no overflow.
          columns.add(
            TextFlowColumnResult(
              frameId: frame.frameId,
              columnIndex: ci,
              bounds: bounds,
              visibleStart: start,
              visibleEnd: start,
              visibleText: '',
              hasOverflow: false,
            ),
          );
          continue;
        }
        final end = _fillColumn(
          story: story,
          start: cursor,
          columnWidth: bounds.bounds.width,
          columnHeight: bounds.bounds.height,
          fontSize: fontSize,
        );
        cursor = end;
        columns.add(
          TextFlowColumnResult(
            frameId: frame.frameId,
            columnIndex: ci,
            bounds: bounds,
            visibleStart: start,
            visibleEnd: end,
            visibleText: story.substring(start, end),
            // Overflow is resolved after the loop: only the last column that
            // received text is flagged when the story is not exhausted.
            hasOverflow: false,
          ),
        );
      }
      // If text remains after every column, mark the last NON-EMPTY column as
      // overflowing (terminal overflow for the final frame; the caller chains
      // subsequent frames). Empty trailing columns are never flagged.
      if (cursor < story.length) {
        for (var ci = columns.length - 1; ci >= 0; ci--) {
          if (columns[ci].visibleEnd > columns[ci].visibleStart) {
            final c = columns[ci];
            columns[ci] = TextFlowColumnResult(
              frameId: c.frameId,
              columnIndex: c.columnIndex,
              bounds: c.bounds,
              visibleStart: c.visibleStart,
              visibleEnd: c.visibleEnd,
              visibleText: c.visibleText,
              hasOverflow: true,
            );
            break;
          }
        }
      }
      frameResults.add(
        TextFlowFrameResult(frameId: frame.frameId, columns: columns),
      );
      if (cursor >= story.length) break;
    }

    return TextFlowResult(
      frames: frameResults,
      storyLength: story.length,
      consumed: cursor,
      overflowLength: story.length - cursor,
    );
  }

  /// Fills one column greedily line by line. Returns the end offset reached.
  int _fillColumn({
    required String story,
    required int start,
    required double columnWidth,
    required double columnHeight,
    required double fontSize,
  }) {
    final lineH = measurement.lineHeight(fontSize);
    if (lineH <= 0 || columnHeight < lineH) {
      return start;
    }
    final maxLines = (columnHeight / lineH).floor();
    if (maxLines <= 0) return start;

    var cursor = start;
    var linesUsed = 0;

    while (cursor < story.length && linesUsed < maxLines) {
      final remainingHeight = (maxLines - linesUsed) * lineH;
      final next = _nextLineBreak(
        story: story,
        start: cursor,
        maxWidth: columnWidth,
        maxHeight: remainingHeight,
        fontSize: fontSize,
      );
      if (next == cursor) {
        break; // Not even one character fits this line (degenerate width).
      }
      cursor = next;
      linesUsed++;
    }
    return cursor;
  }

  /// Returns the offset after the next line's worth of text. Honors explicit
  /// newlines; otherwise wraps on width. Never consumes zero characters when
  /// text remains and at least one character fits (prevents infinite loops).
  int _nextLineBreak({
    required String story,
    required int start,
    required double maxWidth,
    required double maxHeight,
    required double fontSize,
  }) {
    if (start >= story.length) return start;
    final nl = story.indexOf('\n', start);
    final hardBreak = nl == -1 ? story.length : nl;
    final segment = story.substring(start, hardBreak);

    final fit = measurement.charactersThatFit(
      text: segment,
      start: 0,
      maxWidth: maxWidth,
      fontSize: fontSize,
    );

    if (fit <= 0) {
      // Degenerate: width too narrow for even one char. Force one character
      // so the engine makes progress (rendering overflow is the shell's
      // responsibility); only safe when one char actually renders.
      return start + 1 > story.length ? start : start + 1;
    }

    // If the whole hard-broken segment fits, consume it plus the newline.
    if (fit >= segment.length) {
      return hardBreak < story.length ? hardBreak + 1 : hardBreak;
    }
    return start + fit;
  }
}
