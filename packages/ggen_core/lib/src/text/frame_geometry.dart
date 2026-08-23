/// Platform-neutral, rendering-free geometry for GGEN text frames.
///
/// GGEN core must not depend on Flutter (`dart:ui`/`Rect`) so the same layout
/// math runs on the Dart VM, CI and any future platform. This is the only
/// geometry value used by the text-layout engine; the shell maps it to a
/// `ui.Rect` at the rendering boundary.
library;

/// An immutable axis-aligned rectangle in artboard/document units.
///
/// Coordinates are finite. A rectangle is permitted to be empty ([isEmpty])
/// by the layout engine during intermediate calculations, but a frame's
/// *content* rectangle must be positive (see [FrameGeometry.contentOf]).
final class FrameRect {
  const FrameRect.fromLTWH(this.left, this.top, this.width, this.height)
    : assert(left >= 0.0 && left < double.infinity, 'left must be finite'),
      assert(top >= 0.0 && top < double.infinity, 'top must be finite'),
      assert(width >= 0.0 && width < double.infinity, 'width must be finite'),
      assert(
        height >= 0.0 && height < double.infinity,
        'height must be finite',
      );

  /// Convenience constructor from two opposite corners.
  factory FrameRect.fromLTRB(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    if (!right.isFinite || !bottom.isFinite) {
      throw ArgumentError('right/bottom must be finite.');
    }
    return FrameRect.fromLTWH(left, top, right - left, bottom - top);
  }

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  /// Horizontal center.
  double get centerX => left + width / 2;

  /// Vertical center.
  double get centerY => top + height / 2;

  bool get isEmpty => width <= 0 || height <= 0;
  bool get isNotEmpty => !isEmpty;

  /// Whether ([x], [y]) lies within the closed rectangle. A 1px epsilon keeps
  /// hit-tests stable on exact column/frame edges across platforms.
  bool contains(num x, num y, {double epsilon = 1e-9}) =>
      x >= left - epsilon &&
      x <= right + epsilon &&
      y >= top - epsilon &&
      y <= bottom + epsilon;

  /// Whether [other] is fully contained within this rectangle.
  bool containsRect(FrameRect other, {double epsilon = 1e-9}) =>
      other.left >= left - epsilon &&
      other.top >= top - epsilon &&
      other.right <= right + epsilon &&
      other.bottom <= bottom + epsilon;

  /// Whether this rectangle overlaps [other] by more than an optional
  /// [epsilon] (used to prove columns never overlap).
  bool overlaps(FrameRect other, {double epsilon = 1e-9}) {
    if (left >= other.right - epsilon || other.left >= right - epsilon) {
      return false;
    }
    if (top >= other.bottom - epsilon || other.top >= bottom - epsilon) {
      return false;
    }
    return true;
  }

  FrameRect translate(double dx, double dy) =>
      FrameRect.fromLTWH(left + dx, top + dy, width, height);

  @override
  bool operator ==(Object other) =>
      other is FrameRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() =>
      'FrameRect(l=${left.toStringAsFixed(2)}, t=${top.toStringAsFixed(2)}, '
      'w=${width.toStringAsFixed(2)}, h=${height.toStringAsFixed(2)})';
}

/// The content rectangle of a text frame in artboard units.
///
/// A text frame is positioned at ([x], [y]) with outer size ([frameWidth],
/// [frameHeight]) and an interior [innerPadding] that separates the frame
/// edge from the text content. The [contentRect] is where columns and text
/// actually flow. Keeping padding inside the geometry (rather than baked into
/// column math) means column geometry always operates on a clean rectangle.
final class FrameGeometry {
  const FrameGeometry({
    required this.x,
    required this.y,
    required this.frameWidth,
    required this.frameHeight,
    this.innerPadding = 0,
  }) : assert(x >= 0.0 && x < double.infinity, 'x must be finite'),
       assert(y >= 0.0 && y < double.infinity, 'y must be finite'),
       assert(
         frameWidth > 0.0 && frameWidth < double.infinity,
         'frameWidth must be finite and positive',
       ),
       assert(
         frameHeight > 0.0 && frameHeight < double.infinity,
         'frameHeight must be finite and positive',
       ),
       assert(
         innerPadding >= 0.0 && innerPadding < double.infinity,
         'innerPadding must be finite and non-negative',
       );

  final double x;
  final double y;
  final double frameWidth;
  final double frameHeight;
  final double innerPadding;

  /// Outer frame rectangle.
  FrameRect get frameRect => FrameRect.fromLTWH(x, y, frameWidth, frameHeight);

  /// Interior content rectangle after [innerPadding] is removed on all sides.
  FrameRect get contentRect {
    final p = innerPadding;
    final cw = frameWidth - 2 * p;
    final ch = frameHeight - 2 * p;
    if (cw <= 0 || ch <= 0) {
      throw StateError(
        'Frame innerPadding ($p) leaves no content area for frame '
        '${frameWidth}x$frameHeight.',
      );
    }
    return FrameRect.fromLTWH(x + p, y + p, cw, ch);
  }

  FrameGeometry copyWith({
    double? x,
    double? y,
    double? frameWidth,
    double? frameHeight,
    double? innerPadding,
  }) => FrameGeometry(
    x: x ?? this.x,
    y: y ?? this.y,
    frameWidth: frameWidth ?? this.frameWidth,
    frameHeight: frameHeight ?? this.frameHeight,
    innerPadding: innerPadding ?? this.innerPadding,
  );

  @override
  bool operator ==(Object other) =>
      other is FrameGeometry &&
      other.x == x &&
      other.y == y &&
      other.frameWidth == frameWidth &&
      other.frameHeight == frameHeight &&
      other.innerPadding == innerPadding;

  @override
  int get hashCode => Object.hash(x, y, frameWidth, frameHeight, innerPadding);
}
