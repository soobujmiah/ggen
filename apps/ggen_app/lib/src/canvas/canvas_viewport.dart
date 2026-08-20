import 'dart:math' as math;
import 'dart:ui';

/// Viewport state for the original GGEN canvas: scale plus translation from
/// screen space to artboard space.
///
/// Widget-free and immutable: every gesture produces a new viewport, and the
/// math (fit, zoom around a focal point, pan, coordinate mapping) is unit
/// tested without a widget tree. The viewport is presentation state only —
/// it never enters the project, history or journal.
final class CanvasViewport {
  const CanvasViewport({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  static const double minScale = 0.05;
  static const double maxScale = 8.0;

  final double scale;
  final double offsetX;
  final double offsetY;

  /// Initial viewport that fits [artboardWidth]x[artboardHeight] into
  /// [viewportWidth]x[viewportHeight] with a [margin] around the artboard.
  factory CanvasViewport.fit({
    required double artboardWidth,
    required double artboardHeight,
    required double viewportWidth,
    required double viewportHeight,
    double margin = 16,
  }) {
    final availableWidth = viewportWidth - 2 * margin;
    final availableHeight = viewportHeight - 2 * margin;
    final scale = (availableWidth <= 0 || availableHeight <= 0)
        ? 1.0
        : math
              .min(
                availableWidth / artboardWidth,
                availableHeight / artboardHeight,
              )
              .clamp(minScale, maxScale)
              .toDouble();
    return CanvasViewport(
      scale: scale,
      offsetX: (viewportWidth - artboardWidth * scale) / 2,
      offsetY: (viewportHeight - artboardHeight * scale) / 2,
    );
  }

  /// Zooms to [targetScale] keeping the artboard point under the screen
  /// focal point ([focalX], [focalY]) stationary.
  CanvasViewport zoomAt({
    required double focalX,
    required double focalY,
    required double targetScale,
  }) {
    final clamped = targetScale.clamp(minScale, maxScale).toDouble();
    final ratio = clamped / scale;
    return CanvasViewport(
      scale: clamped,
      offsetX: focalX - (focalX - offsetX) * ratio,
      offsetY: focalY - (focalY - offsetY) * ratio,
    );
  }

  CanvasViewport panBy(double dx, double dy) => CanvasViewport(
    scale: scale,
    offsetX: offsetX + dx,
    offsetY: offsetY + dy,
  );

  /// Maps a screen-space point to artboard coordinates.
  Offset toArtboard(Offset screen) =>
      Offset((screen.dx - offsetX) / scale, (screen.dy - offsetY) / scale);

  /// Maps an artboard-space point to screen coordinates.
  Offset toScreen(Offset artboard) =>
      Offset(artboard.dx * scale + offsetX, artboard.dy * scale + offsetY);
}
