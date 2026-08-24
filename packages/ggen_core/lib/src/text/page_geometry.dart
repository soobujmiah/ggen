/// Platform-neutral, rendering-free page geometry for GGEN documents.
///
/// A page is the printable surface a document is laid out on: page size,
/// margins (the live/trim area) and optional bleed (artwork extension
/// beyond the trim for full-bleed printing). GGEN core must not depend on
/// Flutter, so all values are plain doubles in artboard units and every
/// rectangle is derived deterministically (never stored).
///
/// Page margins are a *page-level* concept and must not be confused with
/// [FrameGeometry.innerPadding], which is a *frame-level* inset. Page
/// geometry does not alter frames directly: frames keep flowing inside
/// their own content rectangles. The page substrate exists so multi-page
/// text flow and page-aware frame creation have a validated, serializable
/// model to build on.
library;

import 'frame_geometry.dart';

/// Insets between the page edge and the content (live/trim) area.
///
/// Immutable, fail-closed and JSON-serializable. Zero margins on all sides
/// is the legacy/default page layout, which every document without a margin
/// block decodes to (backward compatible).
final class PageMargins {
  const PageMargins({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  }) : assert(
         top >= 0.0 && top < double.infinity,
         'top must be finite and >= 0',
       ),
       assert(
         right >= 0.0 && right < double.infinity,
         'right must be finite and >= 0',
       ),
       assert(
         bottom >= 0.0 && bottom < double.infinity,
         'bottom must be finite and >= 0',
       ),
       assert(
         left >= 0.0 && left < double.infinity,
         'left must be finite and >= 0',
       );

  /// No margins — the legacy/default page layout.
  static const PageMargins zero = PageMargins();

  /// All four sides set to [value].
  const PageMargins.all(double value)
    : top = value,
      right = value,
      bottom = value,
      left = value;

  /// Left/right set to [horizontal], top/bottom set to [vertical].
  const PageMargins.symmetric({
    required double horizontal,
    required double vertical,
  }) : top = vertical,
       right = horizontal,
       bottom = vertical,
       left = horizontal;

  final double top;
  final double right;
  final double bottom;
  final double left;

  static void _check(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name, 'Margin must be finite and >= 0.');
    }
  }

  // The public const constructor cannot run imperative validation, so the
  // non-const factory [create] is the validated entry point for dynamic
  // input; const values are known-good literals. (Same pattern as
  // ColumnLayout.)

  /// Validated factory for runtime/user input. Throws [ArgumentError] on any
  /// invalid margin; callers never observe a half-valid value.
  factory PageMargins.create({
    double top = 0,
    double right = 0,
    double bottom = 0,
    double left = 0,
  }) {
    _check(top, 'top');
    _check(right, 'right');
    _check(bottom, 'bottom');
    _check(left, 'left');
    return PageMargins(top: top, right: right, bottom: bottom, left: left);
  }

  bool get isZero => top == 0 && right == 0 && bottom == 0 && left == 0;

  bool get isUniform => top == right && right == bottom && bottom == left;

  /// Total horizontal space the margins consume (left + right).
  double get horizontalSpan => left + right;

  /// Total vertical space the margins consume (top + bottom).
  double get verticalSpan => top + bottom;

  PageMargins copyWith({
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) => PageMargins.create(
    top: top ?? this.top,
    right: right ?? this.right,
    bottom: bottom ?? this.bottom,
    left: left ?? this.left,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'top': top,
    'right': right,
    'bottom': bottom,
    'left': left,
  };

  /// Decodes JSON, failing closed on any malformed value. A missing/empty
  /// map decodes to [zero] so legacy documents (no margin block) are valid.
  static PageMargins decodeJson(Object? raw) {
    if (raw == null) return zero;
    if (raw is! Map) {
      throw const FormatException('Page margins must be a JSON object.');
    }
    final map = Map<String, Object?>.from(raw);
    return PageMargins.create(
      top: _margin(map['top'], 'top'),
      right: _margin(map['right'], 'right'),
      bottom: _margin(map['bottom'], 'bottom'),
      left: _margin(map['left'], 'left'),
    );
  }

  static double _margin(Object? value, String name) {
    if (value == null) return 0;
    if (value is num && value.isFinite) return value.toDouble();
    throw FormatException('Page margin "$name" must be a finite number.');
  }

  @override
  bool operator ==(Object other) =>
      other is PageMargins &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);

  @override
  String toString() =>
      'PageMargins(top=$top, right=$right, bottom=$bottom, left=$left)';
}

/// Uniform bleed extension beyond the trim/page edge for full-bleed
/// artwork.
///
/// `0` means no bleed. Bleed is a single uniform value on all four sides;
/// per-side bleed is deliberately NOT represented so it cannot be silently
/// approximated.
final class PageBleed {
  const PageBleed(this.size)
    : assert(
        size >= 0.0 && size < double.infinity,
        'size must be finite and >= 0',
      );

  /// No bleed — the legacy/default page.
  static const PageBleed none = PageBleed(0);

  final double size;

  factory PageBleed.create(double size) {
    if (!size.isFinite || size < 0) {
      throw ArgumentError.value(size, 'size', 'Bleed must be finite and >= 0.');
    }
    return PageBleed(size);
  }

  bool get isNone => size == 0;

  Object toJson() => size;

  /// Decodes JSON, failing closed on malformed values. A missing value
  /// decodes to [none] (legacy documents carry no bleed).
  static PageBleed decodeJson(Object? raw) {
    if (raw == null) return none;
    if (raw is num && raw.isFinite && raw >= 0) {
      return PageBleed(raw.toDouble());
    }
    throw const FormatException('Page bleed must be a finite number >= 0.');
  }

  @override
  bool operator ==(Object other) => other is PageBleed && other.size == size;

  @override
  int get hashCode => size.hashCode;

  @override
  String toString() => 'PageBleed($size)';
}

/// The page's full-bleed artwork region: its content bounds expanded by the
/// page bleed on all four sides.
///
/// Reported in artboard units relative to the page origin (the page's
/// top-left corner at (0, 0)). Unlike [FrameRect] — whose coordinates are
/// non-negative artboard positions — [left]/[top] MAY be negative: a
/// full-bleed page's artwork legitimately extends beyond the page edge
/// (artwork is trimmed to the page at print/export time).
final class BleedBounds {
  const BleedBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  }) : assert(left < double.infinity, 'left must be finite'),
       assert(top < double.infinity, 'top must be finite'),
       assert(
         width > 0.0 && width < double.infinity,
         'width must be finite and positive',
       ),
       assert(
         height > 0.0 && height < double.infinity,
         'height must be finite and positive',
       );

  /// Derives the bleed bounds of a content rectangle expanded by [bleed].
  /// Fails closed on a negative or non-finite bleed.
  factory BleedBounds.fromContent(FrameRect content, double bleed) {
    if (!bleed.isFinite || bleed < 0) {
      throw ArgumentError.value(
        bleed,
        'bleed',
        'Bleed must be finite and >= 0.',
      );
    }
    return BleedBounds(
      left: content.left - bleed,
      top: content.top - bleed,
      width: content.width + 2 * bleed,
      height: content.height + 2 * bleed,
    );
  }

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  /// Whether the non-negative rectangle [frame] lies fully inside these
  /// bounds (same epsilon convention as [FrameRect.containsRect]).
  bool containsFrame(FrameRect frame, {double epsilon = 1e-9}) =>
      frame.left >= left - epsilon &&
      frame.top >= top - epsilon &&
      frame.right <= right + epsilon &&
      frame.bottom <= bottom + epsilon;

  @override
  bool operator ==(Object other) =>
      other is BleedBounds &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() =>
      'BleedBounds(l=${left.toStringAsFixed(2)}, t=${top.toStringAsFixed(2)}, '
      'w=${width.toStringAsFixed(2)}, h=${height.toStringAsFixed(2)})';
}

/// The validated, immutable geometry of one document page.
///
/// Immutable and fail-closed: [create] (and therefore [decodeJson]) rejects
/// invalid dimensions and margins that consume the page. All rectangles are
/// derived on access, so a page can never carry stale geometry.
final class PageGeometry {
  const PageGeometry({
    required this.width,
    required this.height,
    this.margins = PageMargins.zero,
    this.bleed = PageBleed.none,
  }) : assert(
         width > 0.0 && width <= maxDimension,
         'width must be finite in (0, $maxDimension]',
       ),
       assert(
         height > 0.0 && height <= maxDimension,
         'height must be finite in (0, $maxDimension]',
       );

  /// Maximum page dimension in artboard units (matches Artboard validation).
  static const double maxDimension = 1000000;

  final double width;
  final double height;
  final PageMargins margins;
  final PageBleed bleed;

  factory PageGeometry.create({
    required double width,
    required double height,
    PageMargins? margins,
    PageBleed? bleed,
  }) {
    final m = margins ?? PageMargins.zero;
    final b = bleed ?? PageBleed.none;
    // Re-validate through the value factories so [create] is the single
    // fail-closed entry point for dynamic input.
    PageMargins.create(
      top: m.top,
      right: m.right,
      bottom: m.bottom,
      left: m.left,
    );
    PageBleed.create(b.size);
    _checkDimension(width, 'width');
    _checkDimension(height, 'height');

    final contentWidth = width - m.left - m.right;
    final contentHeight = height - m.top - m.bottom;
    if (contentWidth <= 0 || contentHeight <= 0) {
      throw ArgumentError(
        'Margins (top=${m.top}, right=${m.right}, bottom=${m.bottom}, '
        'left=${m.left}) consume the entire $width x $height page; the '
        'content area must remain positive.',
      );
    }
    return PageGeometry(width: width, height: height, margins: m, bleed: b);
  }

  static void _checkDimension(double value, String name) {
    if (!value.isFinite || value <= 0 || value > maxDimension) {
      throw ArgumentError.value(
        value,
        name,
        'Dimension must be finite in (0, $maxDimension].',
      );
    }
  }

  /// The full page rectangle, anchored at the origin.
  FrameRect get pageRect => FrameRect.fromLTWH(0, 0, width, height);

  /// The content (live/trim) area: the page inset by [margins] on all
  /// sides. Deterministic; always contained in [pageRect].
  ///
  /// This is the page-level analogue of [FrameGeometry.contentRect], but it
  /// must NOT be confused with frame-level [FrameGeometry.innerPadding]:
  /// margins shape the page, innerPadding shapes a frame.
  FrameRect get contentBounds => FrameRect.fromLTWH(
    margins.left,
    margins.top,
    width - margins.left - margins.right,
    height - margins.top - margins.bottom,
  );

  /// Full-bleed artwork bounds: [contentBounds] expanded by [bleed] on all
  /// sides. With zero bleed this equals [contentBounds]; otherwise it may
  /// extend beyond [pageRect] by design (artwork is trimmed to the page).
  /// See [BleedBounds] for the negative-offset semantics.
  BleedBounds get bleedBounds =>
      BleedBounds.fromContent(contentBounds, bleed.size);

  /// Whether the full-bleed artwork region stays inside the page (true when
  /// the bleed is small relative to the margins). A page anchored at the
  /// artboard origin can only place artwork in non-negative space, so this
  /// is the placement check a page-aware frame creator uses.
  bool get bleedFitsPage {
    final b = bleedBounds;
    return b.left >= 0 && b.top >= 0 && b.right <= width && b.bottom <= height;
  }

  bool get hasBleed => !bleed.isNone;

  PageGeometry copyWith({
    double? width,
    double? height,
    PageMargins? margins,
    PageBleed? bleed,
  }) => PageGeometry.create(
    width: width ?? this.width,
    height: height ?? this.height,
    margins: margins ?? this.margins,
    bleed: bleed ?? this.bleed,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'width': width,
    'height': height,
    'margins': margins.toJson(),
    'bleed': bleed.toJson(),
  };

  /// Decodes JSON, failing closed on malformed values.
  ///
  /// A missing page block (`null`) decodes to `null`: legacy documents
  /// carry no page data and are treated as having no page. A present block
  /// requires finite `width` and `height`; `margins` and `bleed` are
  /// optional and default to zero.
  static PageGeometry? decodeJson(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('Page geometry must be a JSON object.');
    }
    final map = Map<String, Object?>.from(raw);
    return PageGeometry.create(
      width: _dimension(map['width'], 'width'),
      height: _dimension(map['height'], 'height'),
      margins: PageMargins.decodeJson(map['margins']),
      bleed: PageBleed.decodeJson(map['bleed']),
    );
  }

  static double _dimension(Object? value, String name) {
    if (value == null) {
      throw FormatException('Page geometry is missing "$name".');
    }
    if (value is num && value.isFinite) return value.toDouble();
    throw FormatException('Page "$name" must be a finite number.');
  }

  @override
  bool operator ==(Object other) =>
      other is PageGeometry &&
      other.width == width &&
      other.height == height &&
      other.margins == margins &&
      other.bleed == bleed;

  @override
  int get hashCode => Object.hash(width, height, margins, bleed);

  @override
  String toString() =>
      'PageGeometry(width=$width, height=$height, $margins, $bleed)';
}
