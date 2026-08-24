import 'package:flutter/painting.dart';
import 'package:ggen_core/ggen_core.dart';

import '../controller/studio_controller.dart';
export '../controller/studio_controller.dart'
    show textNodeFrameGeometry, textNodeColumnCount, textNodeGutter, textNodeColumnLayout, textFrameSuccessor;
export '../text_flow/linked_text_flow.dart' show linkCandidates;

/// The geometric primitive type of a shape node.
///
/// Vector Studio Milestone 1 ships with rectangle and ellipse. Future
/// milestones will add path, line and star without changing the existing
/// extension keys.
enum ShapePrimitive {
  rectangle('rectangle'),
  ellipse('ellipse');

  const ShapePrimitive(this.wire);

  /// Wire value stored in a node's `shape_type` extension.
  final String wire;

  static ShapePrimitive fromWire(String? value) {
    if (value == null) {
      // Legacy shapes created before the Milestone 1 primitive field were
      // always filled axis-aligned rectangles. Default to rectangle so no
      // project breaks on load.
      return ShapePrimitive.rectangle;
    }
    switch (value) {
      case 'ellipse':
        return ShapePrimitive.ellipse;
      case 'rectangle':
      default:
        return ShapePrimitive.rectangle;
    }
  }
}

/// Reads validated shape geometry and style from a shape node's extensions.
///
/// Returns null if the node is missing required geometry or carries a
/// malformed payload (fail-closed: malformed shapes are skipped rather than
/// guessed at).
///
/// Required keys: `x`, `y`, `w`, `h`, `fill` (legacy `color` accepted as
/// fill for backwards compatibility). Optional: `stroke`, `stroke_width`
/// (validated non-negative), `shape_type` (default `rectangle`).
NodeShapeGeometry? nodeShapeGeometry(DocumentNode node) {
  final x = node.extensions['x'];
  final y = node.extensions['y'];
  final w = node.extensions['w'];
  final h = node.extensions['h'];
  if (x is! num || y is! num || w is! num || h is! num) return null;
  if (!x.isFinite || !y.isFinite || !w.isFinite || !h.isFinite) return null;
  if (w <= 0 || h <= 0) return null;
  final fillRaw = node.extensions['fill'] ?? node.extensions['color'];
  if (fillRaw is! int) return null;
  final sw = node.extensions['stroke_width'];
  double strokeWidth = 0;
  if (sw is num) {
    if (!sw.isFinite || sw < 0) return null; // malformed
    strokeWidth = sw.toDouble();
  }
  final stroke = _asColorInt(node.extensions['stroke']);
  return NodeShapeGeometry(
    x: x.toDouble(),
    y: y.toDouble(),
    width: w.toDouble(),
    height: h.toDouble(),
    fill: fillRaw,
    stroke: stroke,
    strokeWidth: strokeWidth,
    shapeType: ShapePrimitive.fromWire(
      node.extensions['shape_type'] as String?,
    ),
  );
}

/// Text-frame payload: `x`, `y`, `size`, `text`, `color`.
///
/// `w`/`h`/`columns`/`gutter` are handled separately by the column/flow
/// layer (see [textNodeFrameGeometry]).
TextNodeGeometry? textNodeSimpleGeometry(DocumentNode node) {
  final x = node.extensions['x'];
  final y = node.extensions['y'];
  final size = node.extensions['size'];
  final text = node.extensions['text'];
  final color = node.extensions['color'];
  if (x is! num || y is! num || size is! num || text is! String || color is! int) {
    return null;
  }
  if (!x.isFinite || !y.isFinite || !size.isFinite || size <= 0) return null;
  return TextNodeGeometry(
    x: x.toDouble(),
    y: y.toDouble(),
    size: size.toDouble(),
    text: text,
    color: color,
  );
}

/// Hit-tests a node against an artboard-space point. Returns true when the
/// point falls inside the node's bounding rectangle (shapes) or
/// approximate text box. Ellipse hit testing uses AABB for Milestone 1.
bool hitTestNode(DocumentNode node, Offset artboardPoint) {
  final shape = nodeShapeGeometry(node);
  if (shape != null) {
    final rect = Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height);
    return rect.contains(artboardPoint);
  }
  final text = textNodeSimpleGeometry(node);
  if (text != null) {
    final fg = textNodeFrameRect(node);
    if (fg != null) {
      return Rect.fromLTWH(
        fg.x,
        fg.y,
        fg.frameWidth,
        fg.frameHeight,
      ).contains(artboardPoint);
    }
    final width = text.text.length * text.size * 0.6;
    final height = text.size * 1.4;
    return Rect.fromLTWH(text.x, text.y, width, height).contains(artboardPoint);
  }
  return false;
}

int? _asColorInt(Object? v) {
  if (v is int) return v;
  if (v is num && v.isFinite) return v.toInt();
  return null;
}

/// Returns the frame rectangle for a text node that carries `w`/`h`,
/// otherwise null (legacy label-sized text).
FrameGeometry? textNodeFrameRect(DocumentNode node) {
  final fg = textNodeFrameGeometry(node);
  return fg;
}

/// Geometry + style payload for a shape node.
class NodeShapeGeometry {
  const NodeShapeGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.shapeType = ShapePrimitive.rectangle,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final int fill;
  final int? stroke;
  final double strokeWidth;
  final ShapePrimitive shapeType;

  bool get hasStroke => stroke != null && strokeWidth > 0;

  /// Backwards-compatibility alias: legacy code and tests read `color` for
  /// the fill; Milestone 1 uses `fill` as the canonical key.
  int get color => fill;

  NodeShapeGeometry copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? fill,
    int? stroke,
    double? strokeWidth,
    ShapePrimitive? shapeType,
    bool clearStroke = false,
  }) => NodeShapeGeometry(
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    fill: fill ?? this.fill,
    stroke: clearStroke ? null : (stroke ?? this.stroke),
    strokeWidth: strokeWidth ?? this.strokeWidth,
    shapeType: shapeType ?? this.shapeType,
  );
}

/// Simple text payload for legacy label-sized nodes.
class TextNodeGeometry {
  const TextNodeGeometry({
    required this.x,
    required this.y,
    required this.size,
    required this.text,
    required this.color,
  });

  final double x;
  final double y;
  final double size;
  final String text;
  final int color;
}

/// Backwards-compatibility aliases so existing code that imported the old
/// names from the canvas module continues to work.
typedef NodeGeometry = NodeShapeGeometry;

/// Alias for [nodeShapeGeometry] (legacy name).
NodeShapeGeometry? nodeGeometry(DocumentNode node) => nodeShapeGeometry(node);

/// Alias for [textNodeSimpleGeometry] (legacy name).
TextNodeGeometry? textNodeGeometry(DocumentNode node) =>
    textNodeSimpleGeometry(node);
