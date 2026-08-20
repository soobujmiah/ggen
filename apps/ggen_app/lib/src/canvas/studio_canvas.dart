import 'package:flutter/material.dart';

import 'package:ggen_core/ggen_core.dart';

import '../controller/studio_controller.dart';
import 'canvas_viewport.dart';

/// Original compact-phone canvas: shows the first artboard with pinch-zoom
/// and pan, routes taps to the active tool (draw or text), and detects
/// multi-touch taps (2 fingers = undo, 3 fingers = redo).
///
/// The widget stays presentation-only: all project changes happen through
/// the injected [StudioController] (tool sessions, history, journal), so the
/// canvas never owns document state.
class StudioCanvas extends StatefulWidget {
  const StudioCanvas({
    required this.controller,
    required this.drawEnabled,
    required this.onNodeAdded,
    this.onTextRequest,
    this.onTwoFingerTap,
    this.onThreeFingerTap,
    this.onViewportChanged,
    super.key,
  });

  final StudioController controller;
  final bool drawEnabled;
  final VoidCallback onNodeAdded;

  /// Called with the artboard-space tap point when the Text tool is active.
  final void Function(Offset artboardPoint)? onTextRequest;

  /// Called on a clean two-finger tap (undo by convention).
  final VoidCallback? onTwoFingerTap;

  /// Called on a clean three-finger tap (redo by convention).
  final VoidCallback? onThreeFingerTap;

  /// Test/telemetry hook: called with every viewport change (fit, zoom, pan).
  final ValueChanged<CanvasViewport>? onViewportChanged;

  @override
  State<StudioCanvas> createState() => _StudioCanvasState();
}

class _StudioCanvasState extends State<StudioCanvas> {
  static const int _multiTapMaxDurationMs = 300;
  static const double _multiTapMaxMovement = 20;

  CanvasViewport _viewport = const CanvasViewport(
    scale: 1,
    offsetX: 0,
    offsetY: 0,
  );
  double? _gestureStartScale;
  (double, double, double, double)? _fitKey;

  // Raw multi-touch tap tracking.
  final Map<int, _PointerStamp> _downPointers = <int, _PointerStamp>{};
  int _burstPointerCount = 0;
  DateTime? _burstStart;

  void _reportViewport() => widget.onViewportChanged?.call(_viewport);

  /// Fits the artboard into the canvas only when the canvas or artboard size
  /// changes. Calling fit on every build would reset the user's zoom/pan on
  /// every rebuild (e.g. after a gesture's setState), which a device and
  /// widget-test both catch: the viewport must survive rebuilds.
  void _fitIfNeeded(BoxConstraints constraints, Size artboardSize) {
    final canvasSize = constraints.biggest;
    final key = (
      canvasSize.width,
      canvasSize.height,
      artboardSize.width,
      artboardSize.height,
    );
    if (_fitKey == key) return;
    _fitKey = key;
    _viewport = CanvasViewport.fit(
      artboardWidth: artboardSize.width,
      artboardHeight: artboardSize.height,
      viewportWidth: canvasSize.width,
      viewportHeight: canvasSize.height,
    );
    _reportViewport();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final now = DateTime.now();
    if (_downPointers.isEmpty) {
      _burstStart = now;
      _burstPointerCount = 0;
    }
    _downPointers[event.pointer] = _PointerStamp(
      position: event.localPosition,
      at: now,
    );
    if (_burstStart != null &&
        now.difference(_burstStart!) <
            const Duration(milliseconds: _multiTapMaxDurationMs)) {
      _burstPointerCount++;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final stamp = _downPointers.remove(event.pointer);
    if (stamp == null) return;
    if (_downPointers.isNotEmpty) return;

    // All fingers are up: evaluate the burst.
    final burst = _burstPointerCount;
    final start = _burstStart;
    _burstPointerCount = 0;
    _burstStart = null;
    if (start == null) return;

    final duration = DateTime.now().difference(start);
    final moved =
        (event.localPosition - stamp.position).distance > _multiTapMaxMovement;
    if (duration > const Duration(milliseconds: _multiTapMaxDurationMs) ||
        moved) {
      return; // A pan/zoom or slow gesture: let the regular recognizers act.
    }
    switch (burst) {
      case 2:
        widget.onTwoFingerTap?.call();
      case 3:
        widget.onThreeFingerTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final artboards = widget.controller.project.artboards;
    if (artboards.isEmpty) {
      return const Center(
        child: Text(
          'No artboard',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    final artboard = artboards.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        _fitIfNeeded(constraints, Size(artboard.width, artboard.height));
        return Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUp,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _gestureStartScale = _viewport.scale;
            },
            onScaleUpdate: (details) {
              setState(() {
                // details.scale is cumulative from gesture start, so the
                // target scale derives from the scale captured at start;
                // applying it to the current viewport each update would
                // compound the zoom.
                final start = _gestureStartScale ?? _viewport.scale;
                final target = start * details.scale;
                if (details.scale != 1.0) {
                  // Keep the artboard point under the gesture focal point
                  // stationary while the pinch changes scale.
                  final focal = details.localFocalPoint;
                  _viewport = _viewport.zoomAt(
                    focalX: focal.dx,
                    focalY: focal.dy,
                    targetScale: target,
                  );
                } else {
                  _viewport = _viewport.panBy(
                    details.focalPointDelta.dx,
                    details.focalPointDelta.dy,
                  );
                }
              });
              _reportViewport();
            },
            onScaleEnd: (_) {
              _gestureStartScale = null;
            },
            onTapUp: (details) {
              final artboardPoint = _viewport.toArtboard(
                details.localPosition,
              );
              if (widget.drawEnabled) {
                widget.controller.addShapeNode(
                  artboardPoint.dx,
                  artboardPoint.dy,
                );
                widget.onNodeAdded();
              } else if (widget.onTextRequest != null) {
                widget.onTextRequest!(artboardPoint);
              }
            },
            child: ClipRect(
              child: Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(
                    _viewport.offsetX,
                    _viewport.offsetY,
                    0,
                    1,
                  )
                  ..scaleByDouble(
                    _viewport.scale,
                    _viewport.scale,
                    1,
                    1,
                  ),
                child: SizedBox(
                  width: artboard.width,
                  height: artboard.height,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(blurRadius: 24, color: Colors.black54),
                      ],
                    ),
                    child: Stack(
                      children: [
                        for (final node in artboard.nodes) ..._nodeWidgets(node),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _nodeWidgets(DocumentNode node) {
    if (node.kind == DocumentNodeKind.textFrame) {
      final geometry = textNodeGeometry(node);
      if (geometry == null) return const <Widget>[];
      return <Widget>[
        Positioned(
          left: geometry.x,
          top: geometry.y,
          child: Text(
            geometry.text,
            style: TextStyle(
              fontSize: geometry.size,
              color: Color(geometry.color),
              height: 1.2,
            ),
          ),
        ),
      ];
    }
    final geometry = nodeGeometry(node);
    if (geometry == null) return const <Widget>[];
    return <Widget>[
      Positioned(
        left: geometry.x,
        top: geometry.y,
        width: geometry.width,
        height: geometry.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(geometry.color),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    ];
  }
}

/// Studio geometry payload stored in a node's extensions: `x`, `y`, `w`, `h`
/// in artboard units plus `color` as an ARGB int. Null when the node carries
/// no geometry (nodes from other sources render as the artboard only).
NodeGeometry? nodeGeometry(DocumentNode node) {
  final x = node.extensions['x'];
  final y = node.extensions['y'];
  final w = node.extensions['w'];
  final h = node.extensions['h'];
  final color = node.extensions['color'];
  if (x is! num ||
      y is! num ||
      w is! num ||
      h is! num ||
      color is! int) {
    return null;
  }
  return NodeGeometry(
    x: x.toDouble(),
    y: y.toDouble(),
    width: w.toDouble(),
    height: h.toDouble(),
    color: color,
  );
}

/// Text-frame payload: `x`, `y`, `size`, `text`, `color`.
TextNodeGeometry? textNodeGeometry(DocumentNode node) {
  final x = node.extensions['x'];
  final y = node.extensions['y'];
  final size = node.extensions['size'];
  final text = node.extensions['text'];
  final color = node.extensions['color'];
  if (x is! num || y is! num || size is! num || text is! String || color is! int) {
    return null;
  }
  return TextNodeGeometry(
    x: x.toDouble(),
    y: y.toDouble(),
    size: size.toDouble(),
    text: text,
    color: color,
  );
}

final class NodeGeometry {
  const NodeGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final int color;
}

final class TextNodeGeometry {
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

class _PointerStamp {
  const _PointerStamp({required this.position, required this.at});

  final Offset position;
  final DateTime at;
}
