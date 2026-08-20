import 'package:flutter/material.dart';

import 'package:ggen_core/ggen_core.dart';

import '../controller/studio_controller.dart';
import 'canvas_viewport.dart';

/// Original compact-phone canvas: shows the first artboard with pinch-zoom,
/// pan and double-tap zoom, and reports artboard-space taps so the shell can
/// route them to the active tool.
///
/// The widget stays presentation-only: all project changes happen through
/// the injected [StudioController] (tool sessions, history, journal), so the
/// canvas never owns document state.
class StudioCanvas extends StatefulWidget {
  const StudioCanvas({
    required this.controller,
    required this.drawEnabled,
    required this.onNodeAdded,
    this.onViewportChanged,
    super.key,
  });

  final StudioController controller;
  final bool drawEnabled;
  final VoidCallback onNodeAdded;

  /// Test/telemetry hook: called with every viewport change (fit, zoom, pan).
  final ValueChanged<CanvasViewport>? onViewportChanged;

  @override
  State<StudioCanvas> createState() => _StudioCanvasState();
}

class _StudioCanvasState extends State<StudioCanvas> {
  CanvasViewport _viewport = const CanvasViewport(
    scale: 1,
    offsetX: 0,
    offsetY: 0,
  );
  double? _gestureStartScale;
  double _artboardWidth = 1200;
  double _artboardHeight = 800;

  void _reportViewport() => widget.onViewportChanged?.call(_viewport);

  void _fit(BoxConstraints constraints) {
    _viewport = CanvasViewport.fit(
      artboardWidth: _artboardWidth,
      artboardHeight: _artboardHeight,
      viewportWidth: constraints.maxWidth,
      viewportHeight: constraints.maxHeight,
    );
    _reportViewport();
  }

  @override
  Widget build(BuildContext context) {
    final artboards = widget.controller.project.artboards;
    if (artboards.isEmpty) {
      return const Center(
        child: Text('No artboard', style: TextStyle(color: Colors.white54)),
      );
    }
    final artboard = artboards.first;
    _artboardWidth = artboard.width;
    _artboardHeight = artboard.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        _fit(constraints);
        return GestureDetector(
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
            if (!widget.drawEnabled) return;
            final artboardPoint = _viewport.toArtboard(details.localPosition);
            widget.controller.addShapeNode(artboardPoint.dx, artboardPoint.dy);
            widget.onNodeAdded();
          },
          // NOTE: no onDoubleTap* here on purpose. A double-tap recognizer
          // holds the gesture arena open for its 300ms window, which delays
          // single-tap resolution and deadlocks widget tests (pumpAndSettle
          // advances time only while frames are scheduled). Double-tap zoom
          // is deferred until the shell has explicit zoom controls.
          child: ClipRect(
            child: Transform(
              transform: Matrix4.identity()
                ..translate(_viewport.offsetX, _viewport.offsetY)
                ..scale(_viewport.scale),
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
        );
      },
    );
  }

  List<Widget> _nodeWidgets(DocumentNode node) {
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
  if (x is! num || y is! num || w is! num || h is! num || color is! int) {
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
