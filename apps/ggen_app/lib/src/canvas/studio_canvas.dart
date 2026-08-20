import 'package:flutter/material.dart';

import 'package:ggen_core/ggen_core.dart';

import '../controller/studio_controller.dart';
import 'canvas_viewport.dart';

/// Original compact-phone canvas: shows the first artboard with pinch-zoom
/// and pan, routes taps to the active tool (draw, text, select), and detects
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
    this.selectMode = false,
    this.selectedNodeId,
    this.onTextRequest,
    this.onNodeSelected,
    this.onTwoFingerTap,
    this.onThreeFingerTap,
    this.onViewportChanged,
    super.key,
  });

  final StudioController controller;
  final bool drawEnabled;
  final VoidCallback onNodeAdded;

  /// When true, the Select tool is active: taps hit-test nodes and drags
  /// move the selected node.
  final bool selectMode;

  /// The currently selected node's ID, used to render the selection visual.
  final GgenId? selectedNodeId;

  /// Called with the artboard-space tap point when the Text tool is active.
  final void Function(Offset artboardPoint)? onTextRequest;

  /// Called when the Select tool taps the canvas. [nodeId] is the hit-tested
  /// node or null when the tap missed all nodes (deselect).
  final void Function(GgenId? nodeId)? onNodeSelected;

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

  // Node drag tracking for the Select tool.
  _NodeDrag? _nodeDrag;

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

  /// Hit-tests the first artboard's nodes in reverse z-order (last drawn =
  /// topmost). Returns the node ID under [artboardPoint] or null.
  GgenId? _hitTest(Offset artboardPoint) {
    final artboards = widget.controller.project.artboards;
    if (artboards.isEmpty) return null;
    final nodes = artboards.first.nodes;
    // Reverse order: the last node in the list renders on top.
    for (var i = nodes.length - 1; i >= 0; i--) {
      final node = nodes[i];
      final rect = _nodeRect(node);
      if (rect != null && rect.contains(artboardPoint)) {
        return node.id;
      }
    }
    return null;
  }

  /// Returns the artboard-space bounding rectangle for a node, or null when
  /// the node carries no geometry payload.
  Rect? _nodeRect(DocumentNode node) {
    final shape = nodeGeometry(node);
    if (shape != null) {
      return Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height);
    }
    final text = textNodeGeometry(node);
    if (text != null) {
      // Approximate bounding box from text length and font size.
      final width = text.text.length * text.size * 0.6;
      final height = text.size * 1.4;
      return Rect.fromLTWH(text.x, text.y, width, height);
    }
    return null;
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
              // In select mode, check if the gesture starts on a selected node.
              if (widget.selectMode && widget.selectedNodeId != null) {
                final artboardPoint = _viewport.toArtboard(
                  details.localFocalPoint,
                );
                final hitId = _hitTest(artboardPoint);
                if (hitId == widget.selectedNodeId) {
                  _nodeDrag = _NodeDrag(
                    nodeId: hitId,
                    startScreen: details.localFocalPoint,
                  );
                }
              }
            },
            onScaleUpdate: (details) {
              // If we're dragging a node, update the drag preview.
              if (_nodeDrag != null) {
                final startArtboard = _viewport.toArtboard(
                  _nodeDrag!.startScreen,
                );
                final currentArtboard = _viewport.toArtboard(
                  details.localFocalPoint,
                );
                final dx = currentArtboard.dx - startArtboard.dx;
                final dy = currentArtboard.dy - startArtboard.dy;
                setState(() {
                  _nodeDrag = _nodeDrag!.withDelta(dx, dy);
                });
                return;
              }

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
              // Commit the node drag if one was active.
              if (_nodeDrag != null) {
                final drag = _nodeDrag!;
                _nodeDrag = null;
                // Only commit if there was actual movement (>1 artboard unit).
                if (drag.deltaX.abs() > 1 || drag.deltaY.abs() > 1) {
                  widget.controller.moveNode(
                    drag.nodeId,
                    drag.deltaX,
                    drag.deltaY,
                  );
                }
                return;
              }
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
              } else if (widget.selectMode) {
                // Select tool: hit-test and report.
                final hitId = _hitTest(artboardPoint);
                widget.onNodeSelected?.call(hitId);
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
                        for (final node in artboard.nodes)
                          ..._nodeWidgets(node),
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
    final isSelected = widget.selectedNodeId == node.id;
    final drag = _nodeDrag;
    // Apply live drag offset to the selected node's visual position.
    final dragDx = (drag != null && drag.nodeId == node.id) ? drag.deltaX : 0.0;
    final dragDy = (drag != null && drag.nodeId == node.id) ? drag.deltaY : 0.0;

    if (node.kind == DocumentNodeKind.textFrame) {
      final geometry = textNodeGeometry(node);
      if (geometry == null) return const <Widget>[];
      final widgets = <Widget>[
        Positioned(
          left: geometry.x + dragDx,
          top: geometry.y + dragDy,
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
      if (isSelected) {
        // Approximate selection border for text nodes.
        final width = geometry.text.length * geometry.size * 0.6;
        final height = geometry.size * 1.4;
        widgets.add(
          Positioned(
            left: geometry.x + dragDx - 2,
            top: geometry.y + dragDy - 2,
            width: width + 4,
            height: height + 4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF4E6BFF),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }
      return widgets;
    }
    final geometry = nodeGeometry(node);
    if (geometry == null) return const <Widget>[];
    final widgets = <Widget>[
      Positioned(
        left: geometry.x + dragDx,
        top: geometry.y + dragDy,
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
    if (isSelected) {
      widgets.add(
        Positioned(
          left: geometry.x + dragDx - 2,
          top: geometry.y + dragDy - 2,
          width: geometry.width + 4,
          height: geometry.height + 4,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF4E6BFF),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
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

/// Hit-tests a node's bounding rect against an artboard-space point.
/// Returns true when the point falls inside the node's geometry.
bool hitTestNode(DocumentNode node, Offset artboardPoint) {
  final shape = nodeGeometry(node);
  if (shape != null) {
    return Rect.fromLTWH(
      shape.x,
      shape.y,
      shape.width,
      shape.height,
    ).contains(artboardPoint);
  }
  final text = textNodeGeometry(node);
  if (text != null) {
    final width = text.text.length * text.size * 0.6;
    final height = text.size * 1.4;
    return Rect.fromLTWH(text.x, text.y, width, height).contains(
      artboardPoint,
    );
  }
  return false;
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

/// Tracks an in-progress node drag: the node being moved, where the drag
/// started in screen coordinates, and the cumulative artboard-space delta.
class _NodeDrag {
  const _NodeDrag({
    required this.nodeId,
    required this.startScreen,
    this.deltaX = 0,
    this.deltaY = 0,
  });

  final GgenId nodeId;
  final Offset startScreen;
  final double deltaX;
  final double deltaY;

  _NodeDrag withDelta(double dx, double dy) => _NodeDrag(
    nodeId: nodeId,
    startScreen: startScreen,
    deltaX: dx,
    deltaY: dy,
  );
}

class _PointerStamp {
  const _PointerStamp({required this.position, required this.at});

  final Offset position;
  final DateTime at;
}
