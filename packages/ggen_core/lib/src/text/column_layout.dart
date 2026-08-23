import 'dart:collection';

import 'frame_geometry.dart';

/// Reading order for columns inside a text frame.
///
/// Only [leftToRight] is implemented this milestone. [rightToLeft] is
/// declared (Bangla/English are LTR; Arabic/Hebrew RTL is a real product
/// direction) so serialization can reject it explicitly rather than silently
/// mis-ordering text. Balancing is intentionally out of scope (see
/// [ColumnLayout.balanced]).
enum ColumnDirection { leftToRight, rightToLeft }

/// Canonical column-layout configuration for one text frame.
///
/// Immutable, fail-closed and JSON-serializable. Defaults are one column with
/// zero gutter, which is exactly the behavior every pre-column document
/// decodes to (backward compatible). The model stores configuration only;
/// geometry is derived by [ColumnGeometry.layout] so the same configuration is
/// valid for any frame size and never carries stale rectangles.
///
/// Constraints (enforced at construction and on decode):
///  * [columnCount] >= 1 and <= [maxColumnCount]
///  * [gutter] finite and >= 0
///  * [direction] only [ColumnDirection.leftToRight] this milestone
///  * [balanced] must be false; newspaper balancing is planned, not shipped
final class ColumnLayout {
  const ColumnLayout({
    this.columnCount = 1,
    this.gutter = 0,
    this.direction = ColumnDirection.leftToRight,
    this.balanced = false,
  });

  /// Sensible upper bound. A frame narrower than `(n-1)*gutter` is rejected
  /// at layout time regardless; this stops a malformed document from
  /// allocating millions of columns.
  static const int maxColumnCount = 24;

  final int columnCount;
  final double gutter;
  final ColumnDirection direction;

  /// Whether columns should be height-balanced. ALWAYS false this milestone;
  /// sequential fill is the only implemented strategy. Stored so a future
  /// version can round-trip the intent without ambiguity, but constructing a
  /// layout with `balanced: true` throws (fail closed, no fake capability).
  final bool balanced;

  /// One column, no gutter — the legacy/default frame layout.
  static const ColumnLayout single = ColumnLayout(
    columnCount: 1,
    gutter: 0,
    direction: ColumnDirection.leftToRight,
    balanced: false,
  );

  static void _check(int columnCount, double gutter, ColumnDirection direction,
      bool balanced) {
    if (!columnCount.isFinite || columnCount < 1 || columnCount > maxColumnCount) {
      throw ArgumentError.value(
        columnCount,
        'columnCount',
        'columnCount must be an integer in 1..$maxColumnCount.',
      );
    }
    if (!gutter.isFinite || gutter < 0) {
      throw ArgumentError.value(
        gutter,
        'gutter',
        'gutter must be finite and >= 0.',
      );
    }
    if (direction != ColumnDirection.leftToRight) {
      throw ArgumentError.value(
        direction,
        'direction',
        'Only left-to-right columns are implemented this milestone.',
      );
    }
    if (balanced) {
      throw ArgumentError.value(
        balanced,
        'balanced',
        'Automatic column balancing is not implemented; use sequential fill.',
      );
    }
  }

  // The public const constructor cannot run imperative validation, so the
  // non-const factory [create] is the validated entry point for dynamic
  // input; const defaults are known-good literals.

  /// Validated factory for runtime/user input. Throws [ArgumentError] on any
  /// invalid configuration; callers never observe a half-valid layout.
  factory ColumnLayout.create({
    int columnCount = 1,
    double gutter = 0,
    ColumnDirection direction = ColumnDirection.leftToRight,
    bool balanced = false,
  }) {
    _check(columnCount, gutter, direction, balanced);
    return ColumnLayout(
      columnCount: columnCount,
      gutter: gutter,
      direction: direction,
      balanced: balanced,
    );
  }

  bool get isSingleColumn => columnCount == 1;

  ColumnLayout copyWith({
    int? columnCount,
    double? gutter,
    ColumnDirection? direction,
    bool? balanced,
  }) => ColumnLayout.create(
    columnCount: columnCount ?? this.columnCount,
    gutter: gutter ?? this.gutter,
    direction: direction ?? this.direction,
    balanced: balanced ?? this.balanced,
  );

  /// Canonical JSON shape. Keys are sorted by the project codec and unknown
  /// fields are ignored on decode (project codec policy), but this object
  /// only ever emits its four known fields.
  Map<String, Object?> toJson() => <String, Object?>{
    'columnCount': columnCount,
    'gutter': gutter,
    'direction': direction.name,
    'balanced': balanced,
  };

  /// Decodes JSON, failing closed on any malformed value. A missing/empty map
  /// decodes to [single] so legacy documents (no column block) are valid.
  static ColumnLayout decodeJson(Object? raw) {
    if (raw == null) return single;
    if (raw is! Map) {
      throw const FormatException('Column layout must be a JSON object.');
    }
    final map = Map<String, Object?>.from(raw);

    // columnCount: default 1; reject non-int / out of range.
    final rawCount = map['columnCount'];
    final int columnCount;
    if (rawCount == null) {
      columnCount = 1;
    } else if (rawCount is int) {
      columnCount = rawCount;
    } else if (rawCount is double && rawCount == rawCount.truncateToDouble()) {
      columnCount = rawCount.toInt(); // tolerate 2.0 from lenient encoders
    } else {
      throw const FormatException('Column layout columnCount must be an integer.');
    }

    // gutter: default 0; reject non-finite / negative.
    final rawGutter = map['gutter'];
    final double gutter;
    if (rawGutter == null) {
      gutter = 0;
    } else if (rawGutter is num && rawGutter.isFinite) {
      gutter = rawGutter.toDouble();
    } else {
      throw const FormatException('Column layout gutter must be a finite number.');
    }

    // direction: default ltr; reject unknown / unsupported.
    final rawDirection = map['direction'];
    final ColumnDirection direction;
    if (rawDirection == null) {
      direction = ColumnDirection.leftToRight;
    } else if (rawDirection is String) {
      direction = ColumnDirection.values.firstWhere(
        (d) => d.name == rawDirection,
        orElse: () => throw FormatException(
          'Unknown column direction: $rawDirection.',
        ),
      );
    } else {
      throw const FormatException('Column layout direction must be a string.');
    }

    // balanced: default false; a true value is rejected (not implemented).
    final rawBalanced = map['balanced'];
    final bool balanced;
    if (rawBalanced == null) {
      balanced = false;
    } else if (rawBalanced is bool) {
      balanced = rawBalanced;
    } else {
      throw const FormatException('Column layout balanced must be a boolean.');
    }

    return ColumnLayout.create(
      columnCount: columnCount,
      gutter: gutter,
      direction: direction,
      balanced: balanced,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ColumnLayout &&
      other.columnCount == columnCount &&
      other.gutter == gutter &&
      other.direction == direction &&
      other.balanced == balanced;

  @override
  int get hashCode =>
      Object.hash(columnCount, gutter, direction, balanced);

  @override
  String toString() =>
      'ColumnLayout(columns=$columnCount, gutter=$gutter, '
      'direction=${direction.name}, balanced=$balanced)';
}

/// One computed column rectangle within a frame, in reading order.
final class ColumnBounds {
  const ColumnBounds({
    required this.index,
    required this.bounds,
  });

  /// Zero-based column index in reading order (0 = first).
  final int index;

  /// The column's content rectangle (artboard units).
  final FrameRect bounds;

  @override
  bool operator ==(Object other) =>
      other is ColumnBounds && other.index == index && other.bounds == bounds;

  @override
  int get hashCode => Object.hash(index, bounds);

  @override
  String toString() => 'ColumnBounds($index, $bounds)';
}

/// Result of laying out a [ColumnLayout] inside a content rectangle.
final class ColumnGeometry {
  const ColumnGeometry._({
    required this.layout,
    required this.totalContentBounds,
    required List<ColumnBounds> columnList,
  }) : _columns = columnList;

  final ColumnLayout layout;

  /// The content rectangle the columns were computed for.
  final FrameRect totalContentBounds;

  final List<ColumnBounds> _columns;

  /// Ordered column bounds (reading order). Unmodifiable.
  List<ColumnBounds> get columnBounds =>
      UnmodifiableListView<ColumnBounds>(_columns);

  int get columnCount => _columns.length;
  double get gutter => layout.gutter;

  /// The column at [index] (0-based reading order).
  ColumnBounds operator [](int index) => _columns[index];

  /// Returns the index of the column containing ([x], [y]), or -1 when the
  /// point is outside all columns (including the gutter area).
  int columnAtPoint(num x, num y) {
    for (var i = 0; i < _columns.length; i++) {
      if (_columns[i].bounds.contains(x, y)) return i;
    }
    return -1;
  }

  /// Whether ([x], [y]) is within the total content rectangle at all (a point
  /// in a gutter returns false for [columnAtPoint] but true here).
  bool containsPoint(num x, num y) => totalContentBounds.contains(x, y);

  /// Computes deterministic, non-overlapping equal-width columns for [layout]
  /// inside [content].
  ///
  /// For N columns and gutter G:
  ///   availableWidth = content.width - (N - 1) * G
  ///   columnWidth    = availableWidth / N
  /// Throws [ArgumentError] when the content is too small for the configured
  /// columns/gutter (fail closed — never produces negative/zero columns).
  factory ColumnGeometry.layout({
    required ColumnLayout layout,
    required FrameRect content,
  }) {
    if (content.isEmpty) {
      throw ArgumentError('Content rectangle must be non-empty.');
    }
    final n = layout.columnCount;
    final g = layout.gutter;
    final availableWidth = content.width - (n - 1) * g;
    if (availableWidth <= 0) {
      throw ArgumentError(
        'Frame content width ${content.width} is too small for $n columns '
        'with gutter $g (available width $availableWidth <= 0).',
      );
    }
    final columnWidth = availableWidth / n;
    if (!columnWidth.isFinite || columnWidth <= 0) {
      throw ArgumentError('Computed column width is invalid: $columnWidth.');
    }

    final columns = <ColumnBounds>[];
    for (var i = 0; i < n; i++) {
      final left = content.left + i * (columnWidth + g);
      columns.add(
        ColumnBounds(
          index: i,
          bounds: FrameRect.fromLTWH(
            left,
            content.top,
            columnWidth,
            content.height,
          ),
        ),
      );
    }
    return ColumnGeometry._(
      layout: layout,
      totalContentBounds: content,
      columnList: columns,
    );
  }
}
