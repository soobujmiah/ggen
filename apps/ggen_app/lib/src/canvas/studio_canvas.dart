import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ggen_core/ggen_core.dart';

import '../controller/studio_controller.dart';
import 'canvas_viewport.dart';
import 'canvas_zoom_controller.dart';

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
    this.textEnabled = false,
    this.showZoomOverlay = true,
    this.multiSelectMode = false,
    this.gridVisible = true,
    this.onToggleGrid,
    this.selectedNodeId,
    this.onTextRequest,
    this.onNodeSelected,
    this.onTwoFingerTap,
    this.onThreeFingerTap,
    this.onViewportChanged,
    this.zoomController,
    super.key,
  });

  final StudioController controller;
  final bool drawEnabled;
  final VoidCallback onNodeAdded;

  /// When true, the Select tool is active: taps hit-test nodes and drags
  /// move the selected node.
  final bool selectMode;

  /// When true, the Text tool is active: taps request a text frame through
  /// [onTextRequest]. Kept explicit (like [drawEnabled]) so the text dialog
  /// can never fire while another tool owns the canvas tap — device report:
  /// tapping the canvas in Select mode opened the Add-text dialog because
  /// a non-null [onTextRequest] was mistaken for an active Text tool.
  final bool textEnabled;

  /// Whether the compact in-canvas zoom overlay (+/−/fit/percent) is shown.
  /// The shell hides it on compact phones where the bottom toolbar already
  /// carries undo/redo, layers and zoom buttons (device feedback: duplicated
  /// controls); it stays visible on wide layouts and in immersive mode where
  /// no bottom toolbar exists.
  final bool showZoomOverlay;

  /// When true, Select-tool taps toggle node membership in the
  /// multi-selection instead of replacing it (touch-friendly mobile path;
  /// Shift/Ctrl/Cmd taps do the same on hardware keyboards).
  final bool multiSelectMode;

  /// Whether the artboard grid overlay is drawn (8-unit minor lines with a
  /// 64-unit major every 8th line). Presentation-only view state owned by
  /// the shell; pairs with Ctrl-snap so the snapped positions are visible.
  final bool gridVisible;

  /// Toggles the grid overlay; null hides the grid button (grid is then
  /// controlled elsewhere, e.g. the compact bottom toolbar).
  final VoidCallback? onToggleGrid;

  /// The currently selected node's ID (primary), used to render the
  /// selection visual and resize handles. The full selection is read from
  /// [controller] so every selected node gets a border.
  final GgenId? selectedNodeId;

  /// Called with the artboard-space tap point when the Text tool is active.
  final void Function(Offset artboardPoint)? onTextRequest;

  /// Called when the Select tool taps the canvas. [nodeId] is the hit-tested
  /// node or null when the tap missed all nodes (deselect). [additive] is
  /// true when the tap should toggle membership (multi-select), which the
  /// shell passes to the controller; a plain tap replaces the selection.
  final void Function(GgenId? nodeId, bool additive)? onNodeSelected;

  /// Called on a clean two-finger tap (undo by convention).
  final VoidCallback? onTwoFingerTap;

  /// Called on a clean three-finger tap (redo by convention).
  final VoidCallback? onThreeFingerTap;

  /// Test/telemetry hook: called with every viewport change (fit, zoom, pan).
  final ValueChanged<CanvasViewport>? onViewportChanged;

  /// Optional zoom command channel from the shell (keyboard shortcuts).
  final CanvasZoomController? zoomController;

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
  Offset? _lastDownLocal;

  @override
  void initState() {
    super.initState();
    widget.zoomController?.addListener(_onZoomCommand);
  }

  @override
  void didUpdateWidget(covariant StudioCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoomController != widget.zoomController) {
      oldWidget.zoomController?.removeListener(_onZoomCommand);
      widget.zoomController?.addListener(_onZoomCommand);
    }
  }

  @override
  void dispose() {
    widget.zoomController?.removeListener(_onZoomCommand);
    super.dispose();
  }

  void _onZoomCommand() {
    final scale = widget.zoomController?.consumeScale();
    if (scale != null) {
      zoomTo(scale);
      return;
    }
    final cmd = widget.zoomController?.consumeCommand();
    if (cmd == null) return;
    switch (cmd) {
      case CanvasZoomCommand.zoomIn:
        zoomIn();
      case CanvasZoomCommand.zoomOut:
        zoomOut();
      case CanvasZoomCommand.fitToScreen:
        fitToScreen();
    }
  }
  DateTime? _burstStart;

  // Node drag tracking for the Select tool.
  _NodeDrag? _nodeDrag;

  // Resize handle drag tracking.
  ResizeDrag? _resizeDrag;

  void _reportViewport() => widget.onViewportChanged?.call(_viewport);

  /// Zooms in by 25% around the canvas center.
  void zoomIn() => zoomTo(_viewport.scale * 1.25);

  /// Zooms to an absolute scale around the canvas center, clamped to
  /// [CanvasViewport.minScale] / [maxScale]. Used by preset chips and the
  /// numeric input so the same desktop-quality zoom is reachable from touch
  /// and keyboard (the three deferred zoom items from CHANGELOG).
  void zoomTo(double targetScale) {
    setState(() {
      final artboards = widget.controller.project.artboards;
      if (artboards.isEmpty) return;
      final artboard = artboards.first;
      final centerX = _viewport.offsetX + artboard.width * _viewport.scale / 2;
      final centerY = _viewport.offsetY + artboard.height * _viewport.scale / 2;
      _viewport = _viewport.zoomAt(
        focalX: centerX,
        focalY: centerY,
        targetScale: targetScale,
      );
    });
    _reportViewport();
  }

  /// Zooms out by 20% (inverse of 1.25×) around the canvas center.
  void zoomOut() {
    setState(() {
      final artboards = widget.controller.project.artboards;
      if (artboards.isEmpty) return;
      final artboard = artboards.first;
      final centerX = _viewport.offsetX + artboard.width * _viewport.scale / 2;
      final centerY = _viewport.offsetY + artboard.height * _viewport.scale / 2;
      _viewport = _viewport.zoomAt(
        focalX: centerX,
        focalY: centerY,
        targetScale: _viewport.scale / 1.25,
      );
    });
    _reportViewport();
  }

  /// Fits the artboard into the current canvas constraints.
  void fitToScreen() {
    final artboards = widget.controller.project.artboards;
    if (artboards.isEmpty) return;
    // Use the last known fit key dimensions; reset forces a re-fit.
    _fitKey = null;
    setState(() {});
    _reportViewport();
  }

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
    // Remember where the finger actually touched down: ScaleGestureRecognizer
    // reports onScaleStart *after* the touch slop is crossed, so its focal
    // point has already moved — hit-testing and drag references must use the
    // touch-down position or slow drags can start on the wrong target and
    // the slop distance is lost from the drag delta.
    _lastDownLocal = event.localPosition;
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
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUp,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _gestureStartScale = _viewport.scale;
              // The gesture target is where the finger touched down, not the
              // recognizer's post-slop focal point.
              final gestureStart = _lastDownLocal ?? details.localFocalPoint;
              // In select mode, first check whether the gesture starts on a
              // resize handle of the primary selected node (handles are
              // primary-only this milestone; group resize stays deferred).
              if (widget.selectMode && widget.selectedNodeId != null) {
                final selectedId = widget.selectedNodeId!;
                final artboards = widget.controller.project.artboards;
                if (artboards.isNotEmpty) {
                  final nodes = artboards.first.nodes;
                  final idx = nodes.indexWhere((n) => n.id == selectedId);
                  if (idx >= 0) {
                    final geom = nodeGeometry(nodes[idx]);
                    if (geom != null) {
                      final handles = resizeHandleRects(geom, _viewport);
                      for (final entry in handles.entries) {
                        if (entry.value.contains(gestureStart)) {
                          _resizeDrag = ResizeDrag(
                            nodeId: selectedId,
                            handle: entry.key,
                            startScreen: gestureStart,
                            initialX: geom.x,
                            initialY: geom.y,
                            initialW: geom.width,
                            initialH: geom.height,
                          );
                          return;
                        }
                      }
                    }
                  }
                }
              }
              // Not a handle (or nothing selected yet): check if the gesture
              // starts on a node for a move. Dragging a node that is already
              // part of the current selection moves the WHOLE selection
              // (group move, one undoable step); dragging an unselected node
              // selects it first (replacing the selection) and moves just
              // that node.
              if (widget.selectMode && _resizeDrag == null) {
                final artboardPoint = _viewport.toArtboard(gestureStart);
                final hitId = _hitTest(artboardPoint);
                if (hitId != null) {
                  final selected = widget.controller.selectedNodeIds;
                  if (selected.contains(hitId)) {
                    _nodeDrag = _NodeDrag(
                      nodeIds: selected,
                      startScreen: gestureStart,
                    );
                  } else {
                    widget.onNodeSelected?.call(hitId, false);
                    _nodeDrag = _NodeDrag(
                      nodeIds: <GgenId>[hitId],
                      startScreen: gestureStart,
                    );
                  }
                }
              }
            },
            onScaleUpdate: (details) {
              // If we're resizing a node, update the resize preview.
              if (_resizeDrag != null) {
                final startArtboard = _viewport.toArtboard(
                  _resizeDrag!.startScreen,
                );
                final currentArtboard = _viewport.toArtboard(
                  details.localFocalPoint,
                );
                final dx = currentArtboard.dx - startArtboard.dx;
                final dy = currentArtboard.dy - startArtboard.dy;
                setState(() {
                  _resizeDrag = _resizeDrag!.withDelta(dx, dy);
                });
                return;
              }
              // If we're dragging a node, update the drag preview.
              // Ctrl/Cmd snaps movement to the 8-unit grid.
              if (_nodeDrag != null) {
                final startArtboard = _viewport.toArtboard(
                  _nodeDrag!.startScreen,
                );
                final currentArtboard = _viewport.toArtboard(
                  details.localFocalPoint,
                );
                var dx = currentArtboard.dx - startArtboard.dx;
                var dy = currentArtboard.dy - startArtboard.dy;
                final snap = HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed;
                if (snap) {
                  const grid = 8.0;
                  dx = (dx / grid).round() * grid;
                  dy = (dy / grid).round() * grid;
                }
                setState(() {
                  _nodeDrag = _nodeDrag!.withDelta(dx, dy);
                });
                return;
              }

              setState(() {
                // details.scale is cumulative from gesture start, so the
                // target scale derives from the scale captured at start;
                // applying it to the current viewport each update would
                // compound the zoom. Handle both pinch-zoom and pan
                // simultaneously so two-finger pan+zoom feels fluid (was
                // previously exclusive: scale !=1 ? zoom : pan).
                final start = _gestureStartScale ?? _viewport.scale;
                final target = start * details.scale;
                var next = _viewport;
                if (details.scale != 1.0) {
                  final focal = details.localFocalPoint;
                  next = next.zoomAt(
                    focalX: focal.dx,
                    focalY: focal.dy,
                    targetScale: target,
                  );
                }
                // Always apply the pan delta, even during a pinch, so the
                // canvas follows the fingers without lag.
                if (details.focalPointDelta.dx != 0 || details.focalPointDelta.dy != 0) {
                  next = next.panBy(
                    details.focalPointDelta.dx,
                    details.focalPointDelta.dy,
                  );
                }
                _viewport = next;
              });
              _reportViewport();
            },
            onScaleEnd: (_) {
              // Commit the resize if one was active.
              if (_resizeDrag != null) {
                final drag = _resizeDrag!;
                _resizeDrag = null;
                final proportional =
                    HardwareKeyboard.instance.isShiftPressed;
                final snapToGrid = HardwareKeyboard
                        .instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed;
                final (x, y, w, h) = drag.computeGeometry(
                  proportional: proportional,
                  snapToGrid: snapToGrid,
                );
                // Only commit if the geometry actually changed (>1 unit).
                if ((x - drag.initialX).abs() > 1 ||
                    (y - drag.initialY).abs() > 1 ||
                    (w - drag.initialW).abs() > 1 ||
                    (h - drag.initialH).abs() > 1) {
                  widget.controller.resizeNode(
                    drag.nodeId,
                    x: x,
                    y: y,
                    width: w,
                    height: h,
                  );
                }
                return;
              }
              // Commit the node drag if one was active (a single undoable
              // group move when multiple nodes were dragged).
              if (_nodeDrag != null) {
                final drag = _nodeDrag!;
                _nodeDrag = null;
                // Only commit if there was actual movement (>1 artboard unit).
                if (drag.deltaX.abs() > 1 || drag.deltaY.abs() > 1) {
                  widget.controller.moveNodes(
                    drag.nodeIds,
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
              } else if (widget.selectMode) {
                // Select tool: hit-test and report (never opens the text
                // dialog — regression pinned by the shell test). Shift,
                // Ctrl/Cmd on a hardware keyboard and the shell's
                // multi-select mode toggle all make the tap additive.
                final additive =
                    HardwareKeyboard.instance.isShiftPressed ||
                    HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed ||
                    widget.multiSelectMode;
                final hitId = _hitTest(artboardPoint);
                widget.onNodeSelected?.call(hitId, additive);
              } else if (widget.textEnabled && widget.onTextRequest != null) {
                widget.onTextRequest!(artboardPoint);
              }
            },
            child: ClipRect(
              // The artboard must lay out at its full artboard size even
              // though the parent chain (Positioned.fill -> 471x803) is
              // tight: a tight-constrained SizedBox would force the
              // Transform's child down to the canvas size, collapsing the
              // whole artboard into a small rectangle hugging the left edge
              // (device report: "fit-to-screen shrinks the canvas to the
              // left"). OverflowBox removes the constraint; the outer
              // ClipRect keeps the visible area bounded to the canvas.
              // Note the minima: OverflowBox falls back to the parent's
              // minWidth/minHeight when unset, which re-constrained the box
              // to 471x803 minima (observed as a 1200x803 layout).
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
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
                        // Grid overlay under the nodes (keyed for tests).
                        if (widget.gridVisible)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                key: const ValueKey('ggen_grid_overlay'),
                                painter: _GridPainter(scale: _viewport.scale),
                              ),
                            ),
                          ),
                        for (final node in artboard.nodes)
                          ..._nodeWidgets(node),
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
              ),
            ),
            // Resize handles overlay for the selected shape node.
            if (widget.selectMode && widget.selectedNodeId != null)
              ..._resizeHandleWidgets(),
            // Zoom controls overlay — bottom-right of the canvas. Hidden on
            // compact phones where the bottom toolbar duplicates these.
            if (widget.showZoomOverlay)
              Positioned(
              right: 12,
              bottom: 12,
              child: _ZoomControls(
                scale: _viewport.scale,
                onZoomIn: zoomIn,
                onZoomOut: zoomOut,
                onFit: fitToScreen,
                onZoomToScale: zoomTo,
                gridVisible: widget.gridVisible,
                onToggleGrid: widget.onToggleGrid,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Renders the 8 resize handles for the selected shape node in screen
  /// space. Returns an empty list when no shape node is selected.
  List<Widget> _resizeHandleWidgets() {
    final selectedId = widget.selectedNodeId;
    if (selectedId == null) return const <Widget>[];
    final artboards = widget.controller.project.artboards;
    if (artboards.isEmpty) return const <Widget>[];
    final nodes = artboards.first.nodes;
    final nodeIndex = nodes.indexWhere((n) => n.id == selectedId);
    if (nodeIndex < 0) return const <Widget>[];
    final geometry = nodeGeometry(nodes[nodeIndex]);
    if (geometry == null) return const <Widget>[];

    // Apply live drag offset if this node is being moved.
    final drag = _nodeDrag;
    final dragDx = (drag != null && drag.nodeIds.contains(selectedId))
        ? drag.deltaX
        : 0.0;
    final dragDy = (drag != null && drag.nodeIds.contains(selectedId))
        ? drag.deltaY
        : 0.0;

    // Apply live resize delta if this node is being resized.
    final resizeDrag = _resizeDrag;
    double x = geometry.x + dragDx;
    double y = geometry.y + dragDy;
    double w = geometry.width;
    double h = geometry.height;
    if (resizeDrag != null && resizeDrag.nodeId == selectedId) {
      final proportional = HardwareKeyboard.instance.isShiftPressed;
      final snapToGrid = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      final (rx, ry, rw, rh) = resizeDrag.computeGeometry(
        proportional: proportional,
        snapToGrid: snapToGrid,
      );
      x = rx;
      y = ry;
      w = rw;
      h = rh;
    }

    final handles = resizeHandleRects(
      NodeGeometry(x: x, y: y, width: w, height: h, color: 0),
      _viewport,
    );
    const hs = kHandleSize;
    return <Widget>[
      for (final entry in handles.entries)
        Positioned(
          left: entry.value.left,
          top: entry.value.top,
          width: hs,
          height: hs,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFF4E6BFF),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _nodeWidgets(DocumentNode node) {
    final isSelected = widget.controller.selectedNodeIds.contains(node.id);
    final drag = _nodeDrag;
    // Apply live drag offset to every dragged node's visual position.
    final dragDx = (drag != null && drag.nodeIds.contains(node.id))
        ? drag.deltaX
        : 0.0;
    final dragDy = (drag != null && drag.nodeIds.contains(node.id))
        ? drag.deltaY
        : 0.0;

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

/// Which resize handle is being dragged.
enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// Size of a resize handle hit area in screen pixels.
const double kHandleSize = 10;

/// Returns the screen-space rects for all 8 resize handles of a node with
/// the given artboard-space geometry at the given viewport transform.
Map<ResizeHandle, Rect> resizeHandleRects(
  NodeGeometry geometry,
  CanvasViewport viewport,
) {
  final topLeft = viewport.toScreen(Offset(geometry.x, geometry.y));
  final bottomRight = viewport.toScreen(
    Offset(geometry.x + geometry.width, geometry.y + geometry.height),
  );
  final left = topLeft.dx;
  final top = topLeft.dy;
  final right = bottomRight.dx;
  final bottom = bottomRight.dy;
  final midX = (left + right) / 2;
  final midY = (top + bottom) / 2;
  const hs = kHandleSize;
  Rect handleAt(double cx, double cy) =>
      Rect.fromCenter(center: Offset(cx, cy), width: hs, height: hs);
  return <ResizeHandle, Rect>{
    ResizeHandle.topLeft: handleAt(left, top),
    ResizeHandle.topCenter: handleAt(midX, top),
    ResizeHandle.topRight: handleAt(right, top),
    ResizeHandle.middleLeft: handleAt(left, midY),
    ResizeHandle.middleRight: handleAt(right, midY),
    ResizeHandle.bottomLeft: handleAt(left, bottom),
    ResizeHandle.bottomCenter: handleAt(midX, bottom),
    ResizeHandle.bottomRight: handleAt(right, bottom),
  };
}

/// Tracks an in-progress node drag: the nodes being moved (one or many),
/// where the drag started in screen coordinates, and the cumulative
/// artboard-space delta. A multi-node drag is committed as one group move.
class _NodeDrag {
  const _NodeDrag({
    required this.nodeIds,
    required this.startScreen,
    this.deltaX = 0,
    this.deltaY = 0,
  });

  final List<GgenId> nodeIds;
  final Offset startScreen;
  final double deltaX;
  final double deltaY;

  _NodeDrag withDelta(double dx, double dy) => _NodeDrag(
    nodeIds: nodeIds,
    startScreen: startScreen,
    deltaX: dx,
    deltaY: dy,
  );
}

/// Tracks an in-progress resize handle drag.
class ResizeDrag {
  const ResizeDrag({
    required this.nodeId,
    required this.handle,
    required this.startScreen,
    required this.initialX,
    required this.initialY,
    required this.initialW,
    required this.initialH,
    this.deltaX = 0,
    this.deltaY = 0,
  });

  final GgenId nodeId;
  final ResizeHandle handle;
  final Offset startScreen;
  final double initialX;
  final double initialY;
  final double initialW;
  final double initialH;
  final double deltaX;
  final double deltaY;

  ResizeDrag withDelta(double dx, double dy) => ResizeDrag(
    nodeId: nodeId,
    handle: handle,
    startScreen: startScreen,
    deltaX: dx,
    deltaY: dy,
    initialX: initialX,
    initialY: initialY,
    initialW: initialW,
    initialH: initialH,
  );

  /// Computes the new geometry after applying the artboard-space delta.
  ///
  /// When [proportional] is true, corner handles preserve the initial
  /// aspect ratio (initialW / initialH). Edge-center handles ignore the
  /// flag because they drive a single axis. Shift-proportional resize is a
  /// desktop-quality requirement (see CHANGELOG deferred list) and is
  /// detected via `HardwareKeyboard.instance.isShiftPressed` at the call
  /// sites so the preview stays live while Shift is held/released. The
  /// method itself remains pure for tests.
  ///
  /// When [snapToGrid] is true, the resulting x/y/w/h are snapped to the
  /// nearest [gridSize] (default 8 artboard units, the minimum-size quantum
  /// and the logical grid for GGEN's manual document vertical slice). Ctrl
  /// (or Cmd on macOS) is the snap modifier, mirroring desktop DCC
  /// conventions.
  (double x, double y, double w, double h) computeGeometry({
    bool proportional = false,
    bool snapToGrid = false,
    double gridSize = 8.0,
  }) {
    var x = initialX;
    var y = initialY;
    var w = initialW;
    var h = initialH;
    final dx = deltaX;
    final dy = deltaY;

    // Corner handles with proportional lock: scale uniformly around the
    // opposite corner, driven by the dominant axis change.
    final isCorner = handle == ResizeHandle.topLeft ||
        handle == ResizeHandle.topRight ||
        handle == ResizeHandle.bottomLeft ||
        handle == ResizeHandle.bottomRight;
    if (proportional && isCorner && initialW > 0 && initialH > 0) {
      var rawW = initialW;
      var rawH = initialH;
      switch (handle) {
        case ResizeHandle.topLeft:
          rawW = initialW - dx;
          rawH = initialH - dy;
          break;
        case ResizeHandle.topRight:
          rawW = initialW + dx;
          rawH = initialH - dy;
          break;
        case ResizeHandle.bottomLeft:
          rawW = initialW - dx;
          rawH = initialH + dy;
          break;
        case ResizeHandle.bottomRight:
          rawW = initialW + dx;
          rawH = initialH + dy;
          break;
        default:
          break;
      }
      final aspect = initialW / initialH;
      // Choose scale from the axis that moved more relative to its size.
      final scaleW = rawW / initialW;
      final scaleH = rawH / initialH;
      // Use the larger absolute scale change; guard against zero/negative.
      double scale;
      if (scaleW.isFinite && scaleH.isFinite) {
        // Prefer the axis with larger absolute displacement magnitude.
        final absDx = dx.abs();
        final absDy = dy.abs();
        scale = absDx > absDy ? scaleW : scaleH;
        // If both deltas are tiny, fall back to average to avoid jitter.
        if (absDx < 1 && absDy < 1) {
          scale = (scaleW + scaleH) / 2;
        }
      } else {
        scale = scaleW.isFinite ? scaleW : scaleH;
      }
      if (scale.isFinite && scale > 0) {
        final newW = initialW * scale;
        final newH = initialH * scale;
        // Apply opposite-corner anchoring.
        switch (handle) {
          case ResizeHandle.topLeft:
            x = initialX + initialW - newW;
            y = initialY + initialH - newH;
            w = newW;
            h = newH;
            break;
          case ResizeHandle.topRight:
            x = initialX;
            y = initialY + initialH - newH;
            w = newW;
            h = newH;
            break;
          case ResizeHandle.bottomLeft:
            x = initialX + initialW - newW;
            y = initialY;
            w = newW;
            h = newH;
            break;
          case ResizeHandle.bottomRight:
            x = initialX;
            y = initialY;
            w = newW;
            h = newH;
            break;
          default:
            break;
        }
      } else {
        // Fallback to non-proportional raw if scale degenerate.
        switch (handle) {
          case ResizeHandle.topLeft:
            x += dx; y += dy; w -= dx; h -= dy;
            break;
          case ResizeHandle.topRight:
            y += dy; w += dx; h -= dy;
            break;
          case ResizeHandle.bottomLeft:
            x += dx; w -= dx; h += dy;
            break;
          case ResizeHandle.bottomRight:
            w += dx; h += dy;
            break;
          default:
            break;
        }
      }
    } else {
      switch (handle) {
        case ResizeHandle.topLeft:
          x += dx; y += dy; w -= dx; h -= dy;
          break;
        case ResizeHandle.topCenter:
          y += dy; h -= dy;
          break;
        case ResizeHandle.topRight:
          y += dy; w += dx; h -= dy;
          break;
        case ResizeHandle.middleLeft:
          x += dx; w -= dx;
          break;
        case ResizeHandle.middleRight:
          w += dx;
          break;
        case ResizeHandle.bottomLeft:
          x += dx; w -= dx; h += dy;
          break;
        case ResizeHandle.bottomCenter:
          h += dy;
          break;
        case ResizeHandle.bottomRight:
          w += dx; h += dy;
          break;
      }
    }
    // Enforce minimum size of 8 artboard units.
    if (w < 8) {
      if (handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.middleLeft ||
          handle == ResizeHandle.bottomLeft) {
        x -= (8 - w);
      }
      w = 8;
    }
    if (h < 8) {
      if (handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.topCenter ||
          handle == ResizeHandle.topRight) {
        y -= (8 - h);
      }
      h = 8;
    }
    // Snap to grid after minimum guard so snapped size never goes below 8.
    if (snapToGrid && gridSize > 0) {
      // Simple independent snap; corner-anchoring drift of up to gridSize/2
      // is acceptable for this milestone. A future refinement can snap the
      // fixed edge and derive the moving edge to keep the opposite corner
      // exactly stationary.
      x = (x / gridSize).round() * gridSize;
      y = (y / gridSize).round() * gridSize;
      w = (w / gridSize).round() * gridSize;
      h = (h / gridSize).round() * gridSize;
      if (w < 8) w = 8;
      if (h < 8) h = 8;
    }
    // When proportional, re-assert aspect after clamping (if both dims
    // were clamped, aspect may have drifted — this is acceptable for the
    // minimum-size guard; we keep the clamped square).
    return (x, y, w, h);
  }
}

/// Compact zoom controls overlay: zoom in, zoom out, fit-to-screen buttons
/// and a zoom percentage indicator with presets and numeric input.
///
/// Presets 50/100/200% and a custom numeric dialog are the deferred
/// zoom-quality items from CHANGELOG; tapping the percentage opens a
/// preset sheet so the same desktop-quality zoom is reachable from touch.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.scale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onZoomToScale,
    this.gridVisible = true,
    this.onToggleGrid,
  });

  final double scale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final ValueChanged<double> onZoomToScale;

  /// Grid overlay state for the toggle icon; null callback hides the button
  /// (compact phones control the grid from the bottom toolbar).
  final bool gridVisible;
  final VoidCallback? onToggleGrid;

  @override
  Widget build(BuildContext context) {
    final percent = (scale * 100).round();
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            tooltip: 'Zoom out',
            icon: Icons.remove,
            onPressed: scale > CanvasViewport.minScale ? onZoomOut : null,
          ),
          // Tap the percentage to open zoom presets and numeric input.
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _showZoomPresets(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          _ZoomButton(
            tooltip: 'Zoom in',
            icon: Icons.add,
            onPressed: scale < CanvasViewport.maxScale ? onZoomIn : null,
          ),
          _ZoomButton(
            tooltip: 'Fit to screen',
            icon: Icons.fit_screen_outlined,
            onPressed: onFit,
          ),
          if (onToggleGrid != null)
            _ZoomButton(
              tooltip: gridVisible ? 'Hide grid' : 'Show grid',
              icon: Icons.grid_4x4,
              onPressed: onToggleGrid,
              isSelected: gridVisible,
            ),
        ],
      ),
    );
  }

  void _showZoomPresets(BuildContext context) {
    final presets = <double>[0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 4.0];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Zoom presets',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final preset in presets)
                  ChoiceChip(
                    label: Text('${(preset * 100).round()}%'),
                    selected: (scale - preset).abs() < 0.01,
                    onSelected: (_) {
                      Navigator.pop(sheetContext);
                      onZoomToScale(preset);
                    },
                  ),
                ActionChip(
                  label: const Text('Fit'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onFit();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Custom %', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ZoomCustomField(
                      initialPercent: (scale * 100).round(),
                      onSubmitted: (value) {
                        Navigator.pop(sheetContext);
                        final clamped = value.clamp(
                          (CanvasViewport.minScale * 100).round(),
                          (CanvasViewport.maxScale * 100).round(),
                        );
                        onZoomToScale(clamped / 100);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ZoomCustomField extends StatefulWidget {
  const _ZoomCustomField({
    required this.initialPercent,
    required this.onSubmitted,
  });

  final int initialPercent;
  final ValueChanged<int> onSubmitted;

  @override
  State<_ZoomCustomField> createState() => _ZoomCustomFieldState();
}

class _ZoomCustomFieldState extends State<_ZoomCustomField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPercent.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        hintText: 'e.g. 150',
        suffixText: '%',
      ),
      onSubmitted: (raw) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) widget.onSubmitted(parsed);
      },
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Highlights the toggle button while its mode is active (grid overlay).
  final bool isSelected;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected && onPressed != null
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: onPressed != null ? Colors.white70 : Colors.white24,
          ),
        ),
      ),
    ),
  );
}

/// Draws the artboard grid in artboard coordinates (inside the viewport
/// Transform, so the overlay scales with the artboard). Minor lines every
/// 8 units and a major line every 8th (64 units). Stroke width is divided
/// by the viewport scale so lines stay ~1 screen pixel at any zoom.
///
/// When the minor spacing would fall below ~4.5 screen pixels (distant fit
/// zooms), minor lines are skipped to avoid a moiré wash — a desktop-quality
/// grid stays legible at every zoom level.
class _GridPainter extends CustomPainter {
  _GridPainter({required this.scale});

  final double scale;

  static const double minorStep = 8;
  static const double majorStep = 64;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final strokeWidth = (1 / scale).clamp(0.5, 8.0);
    final minorPaint = Paint()
      ..color = const Color(0x1F7A7A7A)
      ..strokeWidth = strokeWidth;
    final majorPaint = Paint()
      ..color = const Color(0x3D4E6BFF)
      ..strokeWidth = strokeWidth;
    final drawMinor = minorStep * scale >= 4.5;

    // Vertical lines.
    final maxX = size.width;
    for (var i = 0; i * minorStep <= maxX; i++) {
      final x = i * minorStep;
      if (i % (majorStep ~/ minorStep) == 0) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          majorPaint,
        );
      } else if (drawMinor) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
      }
    }
    // Horizontal lines.
    final maxY = size.height;
    for (var i = 0; i * minorStep <= maxY; i++) {
      final y = i * minorStep;
      if (i % (majorStep ~/ minorStep) == 0) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          majorPaint,
        );
      } else if (drawMinor) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.scale != scale;
}

class _PointerStamp {
  const _PointerStamp({required this.position, required this.at});

  final Offset position;
  final DateTime at;
}
