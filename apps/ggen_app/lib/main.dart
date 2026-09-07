import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log.dart';
import 'workspace_preferences.dart';
import 'workspace_profile.dart';
import 'profile_manager_sheet.dart';
import 'src/controller/studio_controller.dart';
import 'src/canvas/studio_canvas.dart';
import 'src/canvas/canvas_zoom_controller.dart';
import 'src/canvas/canvas_viewport.dart';
import 'src/layers/layer_list.dart';
import 'src/text_flow/linked_text_flow.dart';
import 'src/workspace/studio_tool.dart';
import 'src/workspace/control_layout.dart';
import 'src/workspace/workspace_bars.dart';
import 'src/storage/file_project_store.dart';
import 'src/storage/file_recovery_journal.dart';
import 'src/storage/saved_project_summary.dart';

import 'package:ggen_core/ggen_core.dart';

final debugLog = DebugLogStore()..info('app_start', 'GGEN shell started');

/// Platform channel for debug intent actions from Android.
/// Accessed via: adb shell am start -n com.example.ggen/com.example.ggen_app.DebugActivity --es test_action <action>
final MethodChannel _debugChannel = MethodChannel('com.example.ggen/debug');

/// Global reference to the current controller for debug actions.
/// Set by the shell when initialized; accessed by the platform channel handler.
StudioController? _debugStudioController;

void _setupDebugChannel() {
  _debugChannel.setMethodCallHandler((call) async {
    if (call.method != 'debugAction') return;
    final args = call.arguments as Map?;
    _handleDebugAction(args);
  });
}

void _handleDebugAction(dynamic args) {
  if (args is! Map || _debugStudioController == null) return;
  final action = args['action'] as String?;
  if (action == null) return;
  final controller = _debugStudioController!;
  debugLog.info('debug_intent', 'Debug action received: $action');
  switch (action) {
    case 'undo':
      if (controller.canUndo) controller.undo();
      break;
    case 'redo':
      if (controller.canRedo) controller.redo();
      break;
    case 'grid':
      // Grid toggle handled via setState in the shell
      break;
    case 'zoom_in':
      // Zoom requires canvas reference; skip for now
      break;
    case 'zoom_out':
      break;
    case 'fit':
      break;
    case 'save':
      // Save triggers UI; not available via intent
      break;
  }
}

/// File-based debug command interface.
/// 
/// An agent writes a JSON command to `/data/user/0/com.example.ggen/app_flutter/debug_cmd.json`:
/// ```json
/// {"cmd": "link", "source": "text-1", "target": "text-2"}
/// ```
/// 
/// Flutter polls this file every 500ms, executes the command, and appends
/// the result to the debug log. This enables full autonomous qualification
/// without requiring manual UI interaction.
/// 
/// Supported commands:
/// - `state` - return current project state (nodes, selection, revision)
/// - `undo` / `redo` - history operations
/// - `link` / `unlink` - linked text flow operations (requires `source`, `target`)
/// - `group` / `ungroup` - group operations (requires `nodes` list)
/// - `addShape` / `addText` - create objects (requires `x`, `y`)
/// - `select` / `move` / `delete` - node operations
/// - `save` / `load` - persistence operations
/// - `clear` - clear all debug commands
Future<void> _processDebugCommands() async {
  if (_debugStudioController == null) return;
  
  try {
    final docs = await getApplicationDocumentsDirectory();
    final cmdFile = File('${docs.path}/debug_cmd.json');
    if (!cmdFile.existsSync()) return;
    
    final content = await cmdFile.readAsString();
    if (content.trim().isEmpty) return;
    
    // Clear command file immediately to prevent re-execution
    await cmdFile.writeAsString('');
    
    final Map<String, Object?> cmd;
    try {
      cmd = jsonDecode(content) as Map<String, Object?>;
    } catch (e) {
      debugLog.warning('debug_cmd', 'Invalid JSON command', {'error': e.toString()});
      return;
    }
    
    final command = cmd['cmd'] as String?;
    if (command == null) return;
    
    final controller = _debugStudioController!;
    final Map<String, Object?> result = {'cmd': command};
    
    switch (command) {
      case 'state':
        result['revision'] = controller.revision;
        result['objectCount'] = controller.objectCount;
        result['canUndo'] = controller.canUndo;
        result['canRedo'] = controller.canRedo;
        result['selectedNodeIds'] = controller.selectedNodeIds.map((e) => e.value).toList();
        result['nodes'] = controller.project.artboards.first.nodes.map((n) => <String, Object?>{
          'id': n.id.value,
          'name': n.name,
          'x': n.extensions['x'],
          'y': n.extensions['y'],
          'w': n.extensions['w'],
          'h': n.extensions['h'],
          'text': n.extensions['text'],
          'nextFrame': n.extensions['nextFrame'],
        }).toList();
        break;
        
      case 'undo':
        if (controller.canUndo) {
          controller.undo();
          result['success'] = true;
          result['revision'] = controller.revision;
        } else {
          result['success'] = false;
          result['error'] = 'Nothing to undo';
        }
        break;
        
      case 'redo':
        if (controller.canRedo) {
          controller.redo();
          result['success'] = true;
          result['revision'] = controller.revision;
        } else {
          result['success'] = false;
          result['error'] = 'Nothing to redo';
        }
        break;
        
      case 'addShape':
        final x = (cmd['x'] as num?)?.toDouble() ?? 100;
        final y = (cmd['y'] as num?)?.toDouble() ?? 100;
        controller.addShapeNode(x, y);
        result['success'] = true;
        result['revision'] = controller.revision;
        break;
        
      case 'addText':
        final x = (cmd['x'] as num?)?.toDouble() ?? 100;
        final y = (cmd['y'] as num?)?.toDouble() ?? 100;
        final text = cmd['text'] as String? ?? 'Hello';
        controller.addTextNode(x, y, text);
        result['success'] = true;
        result['revision'] = controller.revision;
        break;
        
      case 'link':
        final sourceId = cmd['source'] as String?;
        final targetId = cmd['target'] as String?;
        if (sourceId == null || targetId == null) {
          result['success'] = false;
          result['error'] = 'Missing source or target';
        } else {
          try {
            final ok = controller.linkTextFrames(GgenId(sourceId), GgenId(targetId));
            result['success'] = ok;
          } catch (e) {
            result['success'] = false;
            result['error'] = e.toString();
          }
        }
        break;
        
      case 'unlink':
        final sourceId = cmd['source'] as String?;
        if (sourceId == null) {
          result['success'] = false;
          result['error'] = 'Missing source';
        } else {
          final ok = controller.unlinkTextFrame(GgenId(sourceId));
          result['success'] = ok;
        }
        break;
        
      case 'group':
        final nodeIds = (cmd['nodes'] as List?)?.cast<String>() ?? [];
        if (nodeIds.isEmpty) {
          result['success'] = false;
          result['error'] = 'Missing nodes';
        } else {
          final ok = controller.createGroup(nodeIds.map((e) => GgenId(e)).toList());
          result['success'] = ok;
        }
        break;
        
      case 'select':
        final nodeId = cmd['node'] as String?;
        if (nodeId != null) {
          controller.selectNode(GgenId(nodeId));
          result['success'] = true;
        } else {
          controller.deselectNode();
          result['success'] = true;
        }
        break;
        
      case 'move':
        final nodeId = cmd['node'] as String?;
        final dx = (cmd['dx'] as num?)?.toDouble() ?? 0;
        final dy = (cmd['dy'] as num?)?.toDouble() ?? 0;
        if (nodeId != null) {
          final ok = controller.moveNode(GgenId(nodeId), dx, dy);
          result['success'] = ok;
        } else {
          result['success'] = false;
          result['error'] = 'Missing node';
        }
        break;
        
      case 'delete':
        final nodeId = cmd['node'] as String?;
        if (nodeId != null) {
          final ok = controller.deleteNode(GgenId(nodeId));
          result['success'] = ok;
        }
        break;
        
      case 'setText':
        final nodeId = cmd['node'] as String?;
        final text = cmd['text'] as String?;
        if (nodeId != null && text != null) {
          final ok = controller.updateTextNode(GgenId(nodeId), text: text);
          result['success'] = ok;
        } else {
          result['success'] = false;
          result['error'] = 'Missing node or text';
        }
        break;
        
      case 'save':
        await controller.save();
        result['success'] = true;
        result['receipt'] = controller.lastReceipt?.toJson();
        break;
        
      case 'load':
        final ok = await controller.restore(controller.storageKey);
        result['success'] = ok;
        break;
        
      case 'newProject':
        controller.newProject('Untitled project');
        result['success'] = true;
        break;
        
      default:
        result['success'] = false;
        result['error'] = 'Unknown command: $command';
    }
    
    debugLog.info('debug_cmd', 'Command executed', result);
  } catch (e) {
    debugLog.error('debug_cmd', 'Command processing error', {'error': e.toString()});
  }
}

final Set<String> _loggedLayoutModes = <String>{};

/// How long the fullscreen floating controls stay fully prominent after the
/// last interaction. When idle they fade to a subdued opacity IN PLACE —
/// they never relocate and never disappear. Public so widget tests can pump
/// exactly this duration.
const Duration kFullscreenIdleTimeout = Duration(seconds: 6);

/// The fullscreen floating control clusters de-emphasize visually after
/// [kFullscreenIdleTimeout] of inactivity, IN PLACE (they never relocate).
/// The fade stops at this opacity — clearly visible enough to stay
/// discoverable and usable on-device; any interaction restores full
/// prominence.
const double kFullscreenIdleOpacity = 0.82;

enum InspectorDock { left, right }

final Set<String> _loggedCanvasGeometries = <String>{};
DateTime? _lastGeometryLogAt;

/// Records the canvas bounds for diagnostics.
///
/// Sheet animations resize the canvas by ~1px per frame, so a per-pixel
/// dedupe alone would still log dozens of entries per animation (observed on
/// the Redmi: ~50 entries in a few seconds while the settings sheet opened),
/// drowning out meaningful events and evicting them from the bounded log.
/// The key is quantized to [geometryQuantum] pixels and a cooldown gates how
/// often a *different* quantized size can be logged; the exact rounded size
/// is recorded when a log does happen, so settled geometry evidence stays
/// precise.
void recordCanvasGeometry(BuildContext context, Size size, {bool suppress = false}) {
  if (suppress) return;
  if (size.width <= 0 || size.height <= 0) return;
  const quantum = 8;
  final widthRounded = size.width.round();
  final heightRounded = size.height.round();
  final key =
      '${(widthRounded / quantum).round()}x${(heightRounded / quantum).round()}';
  final now = DateTime.now();
  final cooldownElapsed =
      _lastGeometryLogAt == null ||
      now.difference(_lastGeometryLogAt!) >= const Duration(milliseconds: 500);
  if (cooldownElapsed && _loggedCanvasGeometries.add(key)) {
    _lastGeometryLogAt = now;
    final padding = MediaQuery.paddingOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    debugLog.info('canvas_geometry', 'Canvas bounds measured', {
      'width': widthRounded,
      'height': heightRounded,
      'safe_top': padding.top.round(),
      'safe_bottom': padding.bottom.round(),
      'keyboard_bottom': insets.bottom.round(),
    });
  }
}

void _recordLayout(String mode, Size size) {
  // Flutter can briefly report zero constraints during the first frame.
  // Never export that transient value as device layout evidence.
  if (size.width <= 0 || size.height <= 0) return;
  if (_loggedLayoutModes.add(mode)) {
    debugLog.info('layout_mode', 'Workspace layout selected', {
      'mode': mode,
      'width': size.width.round(),
      'height': size.height.round(),
    });
  }
}

void main() {
  FlutterError.onError = (details) {
    debugLog.error('flutter_error', details.exceptionAsString(), {
      'library': details.library ?? 'unknown',
    });
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugLog.error('uncaught_error', error.toString(), {
      'stack': stack.toString(),
    });
    return false;
  };
  // Initialize persistent debug log file for ADB access
  unawaited(debugLog.initLogFile());
  runApp(const GgenApp());
}

Future<void> _showDiagnostics(BuildContext context) async {
  debugLog.info('diagnostics_export', 'Diagnostics JSON opened');
  final payload = debugLog.exportJson();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Diagnostics export'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(child: SelectableText(payload)),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: payload));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Copy JSON'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class GgenApp extends StatelessWidget {
  const GgenApp({super.key, this.controller});

  /// Optional injected controller for tests; the shell owns a default
  /// controller when none is provided.
  final StudioController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGEN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff4e6bff),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: StudioShell(controller: controller),
    );
  }
}

/// Live state of one free-form fullscreen cluster drag. Positions are
/// tracked in the fullscreen Stack's local coordinate space so the math is
/// exact regardless of where the app is on screen, and the drag-start
/// values allow a canceled gesture to restore the exact previous position.
class _ClusterDragSession {
  _ClusterDragSession({
    required this.id,
    required this.startPosition,
    required this.startTopLeft,
    required this.pointerStartLocal,
    required this.clusterSize,
    required this.viewport,
    required this.safe,
    required this.stackBox,
  });

  final String id;

  /// Normalized position at drag start (restored if the drag is canceled).
  final Offset startPosition;

  /// Cluster top-left in stack-local pixels at drag start.
  final Offset startTopLeft;

  /// Pointer position (stack-local) when the long press was accepted.
  final Offset pointerStartLocal;

  final Size clusterSize;
  final Size viewport;
  final EdgeInsets safe;
  final RenderBox stackBox;
}

class StudioShell extends StatefulWidget {
  const StudioShell({super.key, this.controller});

  final StudioController? controller;

  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  late StudioController _studio;
  late final bool _ownsStudio;
  bool _immersive = false;
  bool _showInspector = true;
  bool _showLayers = false;
  bool _multiSelect = false;
  bool _showGrid = true;
  Timer? _debugCmdTimer; // Poll for file-based debug commands
  List<EditorTopAction> _topActionOrder = List<EditorTopAction>.of(
    EditorTopAction.values,
  );
  Set<EditorTopAction> _topActionPinned = <EditorTopAction>{};
  final CanvasZoomController _zoomController = CanvasZoomController();
  bool _canvasFirst = true;
  bool _hasCheckedForegroundAction = false; // Track if we've checked for debug actions
  bool _workspaceSettingsOpen = false;
  InspectorDock _inspectorDock = InspectorDock.right;

  /// User-defined fullscreen (immersive) control placement: free-form
  /// floating clusters, each with its own normalized position. Normalized
  /// by [CanvasControlLayout.resolve] so rendering is always deterministic
  /// and the immersive exit control is always present.
  CanvasControlLayout _fullscreenLayout = CanvasControlLayout.defaults()
      .resolve();

  /// Storage key of the most recently saved/opened project. Kept in shell
  /// state so EVERY workspace preference save (not only the Save action)
  /// preserves it — previously an unrelated preference change silently
  /// cleared the startup-restore key.
  String? _lastProjectKey;

  /// Idle visual de-emphasis of the fullscreen floating controls: subdued
  /// opacity while unused, restored to full prominence on any interaction.
  /// Position and visibility are never affected by idle.
  bool _fullscreenIdle = false;
  Timer? _fullscreenIdleTimer;

  /// True while the stored fullscreen-cluster config is empty (the user
  /// has never customized placement). In that state the built-in defaults
  /// are orientation-aware: portrait keeps the familiar corner
  /// arrangement, landscape moves the clusters to the LEFT and RIGHT sides
  /// so the center stays maximum canvas. The first customization
  /// materializes the currently rendered defaults into real user state.
  bool _fullscreenLayoutIsDefault = true;

  /// Active free-form fullscreen cluster drag, or null while not dragging.
  _ClusterDragSession? _clusterDrag;

  /// Last time a `cluster_drag_update` diagnostic was emitted (throttled).
  DateTime? _lastClusterDragUpdateLog;

  /// The immersive-mode body Stack; its RenderBox converts global pointer
  /// positions into the Stack's local coordinate space during cluster
  /// drags (exact regardless of SafeArea/inset offsets).
  final GlobalKey _fullscreenStackKey = GlobalKey();

  /// The active primary tool. Typed ([StudioTool]) rather than a raw index:
  /// the on-device RangeError ("Not in inclusive range 0..2: 3") happened
  /// because the old 4-destination bottom NavigationBar forwarded its raw
  /// destination index (3 = the contextual Columns entry) into a 3-entry
  /// tool-name list. A [StudioTool] value cannot be out of range.
  StudioTool _tool = StudioTool.select;

  void _selectTool(StudioTool tool) {
    setState(() => _tool = tool);
    debugLog.info('tool_select', 'Tool selected', {
      'index': tool.index,
      'tool': tool.label,
    });
  }

  void _toggleGrid() {
    setState(() => _showGrid = !_showGrid);
    debugLog.info(
      'grid_toggle',
      _showGrid ? 'Grid overlay enabled' : 'Grid overlay disabled',
    );
  }

  /// Debug command handler: responds to Ctrl+D key sequences for automated testing.
  /// Ctrl+D U = undo, Ctrl+D R = redo, Ctrl+D G = toggle grid,
  /// Ctrl+D ZI = zoom in, Ctrl+D ZO = zoom out, Ctrl+D ZF = fit screen
  bool _handleDebugKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!isCtrl) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyD) {
      // Next key in sequence determines action
      debugLog.info('debug_input', 'Debug mode activated', {
        'command': 'debug_d_pressed',
      });
      return true;
    }

    // Single-key debug commands (without D)
    switch (key) {
      case LogicalKeyboardKey.keyU: // Undo
        if (_studio.canUndo) {
          _studio.undo();
          debugLog.info('debug_undo', 'Debug undo triggered', {
            'revision': _studio.revision,
          });
        }
        return true;
      case LogicalKeyboardKey.keyR: // Redo
        if (_studio.canRedo) {
          _studio.redo();
          debugLog.info('debug_redo', 'Debug redo triggered', {
            'revision': _studio.revision,
          });
        }
        return true;
      case LogicalKeyboardKey.keyG: // Toggle grid
        _toggleGrid();
        return true;
      case LogicalKeyboardKey.equal: // Zoom in
        _zoomController.zoomIn();
        debugLog.info('debug_zoom_in', 'Debug zoom in triggered');
        return true;
      case LogicalKeyboardKey.minus: // Zoom out
        _zoomController.zoomOut();
        debugLog.info('debug_zoom_out', 'Debug zoom out triggered');
        return true;
      case LogicalKeyboardKey.digit0: // Fit to screen
        _zoomController.fitToScreen();
        debugLog.info('debug_zoom_fit', 'Debug fit to screen triggered');
        return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _ownsStudio = widget.controller == null;
    _studio = widget.controller ?? StudioController();
    // Wire global reference for debug actions.
    _debugStudioController = _studio;
    _setupDebugChannel();
    _studio.addListener(_onStudioChanged);
    _restoreWorkspace();
    unawaited(_initStorage());
    // Check for pending debug action from DebugActivity.
    unawaited(_checkPendingDebugAction());
    // Start polling for file-based debug commands.
    _startDebugCommandPolling();
    HardwareKeyboard.instance.addHandler(_handleVolumeKey);
    HardwareKeyboard.instance.addHandler(_handleDebugKey);
  }

  void _onStudioChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant StudioShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check for pending debug action when app comes to foreground.
    if (!_hasCheckedForegroundAction) {
      _hasCheckedForegroundAction = true;
      unawaited(_checkPendingDebugAction());
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onStudioChanged);
      // Re-wire to the new controller (injected for tests).
      // When the shell owns its controller, this path is not taken,
      // but keep it correct for the test harness.
      if (widget.controller != null) {
        _studio.removeListener(_onStudioChanged);
        _studio = widget.controller!;
        _studio.addListener(_onStudioChanged);
      }
    }
  }

  @override
  void dispose() {
    _debugCmdTimer?.cancel();
    _fullscreenIdleTimer?.cancel();
    _studio.removeListener(_onStudioChanged);
    // Method tear-offs of the same method on the same instance compare
    // equal, so this removes the handler added in initState.
    HardwareKeyboard.instance.removeHandler(_handleVolumeKey);
    HardwareKeyboard.instance.removeHandler(_handleDebugKey);
    if (_ownsStudio) _studio.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  /// Poll for file-based debug commands every 500ms.
  /// This enables full autonomous agent testing via ADB.
  void _startDebugCommandPolling() {
    _debugCmdTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        await _processDebugCommands();
      } catch (e) {
        debugLog.error('debug_cmd', 'Polling error', {'error': e.toString()});
      }
    });
  }

  /// Volume buttons act as undo (down) and redo (up) while editing. The
  /// event is consumed so the system volume does not change. Delete and
  /// Backspace delete the selected node when the Select tool is active.
  bool _handleVolumeKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.audioVolumeDown) {
      if (!_studio.canUndo) return true;
      _studio.undo();
      debugLog.info('volume_undo', 'Volume-down undo', {
        'revision': _studio.revision,
      });
      return true;
    }
    if (key == LogicalKeyboardKey.audioVolumeUp) {
      if (!_studio.canRedo) return true;
      _studio.redo();
      debugLog.info('volume_redo', 'Volume-up redo', {
        'revision': _studio.revision,
      });
      return true;
    }
    // Delete / Backspace removes every selected node (one history step).
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      final selected = _studio.selectedNodeIds;
      if (selected.isEmpty) return false;
      _studio.deleteNodes(selected);
      debugLog.info('key_delete', 'Nodes deleted via keyboard', {
        'count': selected.length,
        'revision': _studio.revision,
      });
      return true;
    }
    // Ctrl+= / Ctrl++ zooms in, Ctrl+- zooms out, Ctrl+0 fits to screen.
    // Ctrl+1/2/3 are presets 50/100/200% (deferred zoom-quality items).
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isCtrl) {
      if (key == LogicalKeyboardKey.equal ||
          key == LogicalKeyboardKey.numpadAdd) {
        _zoomController.zoomIn();
        debugLog.info('key_zoom_in', 'Ctrl+= zoom in');
        return true;
      }
      if (key == LogicalKeyboardKey.minus ||
          key == LogicalKeyboardKey.numpadSubtract) {
        _zoomController.zoomOut();
        debugLog.info('key_zoom_out', 'Ctrl+- zoom out');
        return true;
      }
      if (key == LogicalKeyboardKey.digit0 ||
          key == LogicalKeyboardKey.numpad0) {
        _zoomController.fitToScreen();
        debugLog.info('key_zoom_fit', 'Ctrl+0 fit to screen');
        return true;
      }
      if (key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.numpad1) {
        _zoomController.zoomTo(0.5);
        debugLog.info('key_zoom_preset', 'Ctrl+1 zoom 50%');
        return true;
      }
      if (key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.numpad2) {
        _zoomController.zoomTo(1.0);
        debugLog.info('key_zoom_preset', 'Ctrl+2 zoom 100%');
        return true;
      }
      if (key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.numpad3) {
        _zoomController.zoomTo(2.0);
        debugLog.info('key_zoom_preset', 'Ctrl+3 zoom 200%');
        return true;
      }
    }
    return false;
  }

  /// Text tool: prompts for the text and commits a text frame node through a
  /// core tool session at the tapped artboard point.
  Future<void> _addTextAt(Offset artboardPoint) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _TextEntryDialog(),
    );
    final trimmed = (text ?? '').trim();
    if (!mounted || trimmed.isEmpty) return;
    _studio.addTextNode(artboardPoint.dx, artboardPoint.dy, trimmed);
    debugLog.info('node_add_text', 'Text frame added by Text tool', {
      'text': trimmed,
      'object_count': _studio.objectCount,
      'revision': _studio.revision,
    });
  }

  /// Swaps the shell-owned controller onto the file-backed store and
  /// journal once the platform documents directory is known.
  ///
  /// The store/journal adapters are pure Dart and take the directory
  /// explicitly; only this resolution needs the platform plugin. When the
  /// plugin is unavailable (tests, unsupported platform) the controller
  /// stays on the in-memory adapters, which is a fully functional fallback.
  Future<void> _initStorage() async {
    if (!_ownsStudio) return;
    try {
      final documents = await getApplicationDocumentsDirectory();
      final next = StudioController(
        store: FileProjectStore(documents),
        journal: FileRecoveryJournal(
          documents,
          AutosavePolicy(
            maxJournalEntries: 200,
            maxJournalBytes: 1 << 20,
            checkpointEveryTransactions: 16,
          ),
        ),
      );
      final previous = _studio;
      _studio = next;
      previous.dispose();
      debugLog.info('storage_init', 'File-backed storage initialized', {
        'path': documents.path,
      });
    } on MissingPluginException {
      debugLog.warning(
        'storage_init',
        'File storage plugin unavailable; using in-memory storage',
      );
    } catch (error) {
      debugLog.warning('storage_init', 'File storage unavailable', {
        'error': error.toString(),
      });
    }
    if (!mounted) return;
    setState(() {});
    await _restoreLastProject();
  }

  /// Restores the most recently saved project on startup, if any. A missing,
  /// stale or malformed stored key is fail-closed: the workspace simply
  /// starts fresh and the condition is recorded in diagnostics.
  Future<void> _restoreLastProject() async {
    final prefs = await WorkspacePreferences.load();
    final key = prefs.lastProjectKey;
    if (key == null) {
      debugLog.info('project_restore', 'No prior project stored');
      return;
    }
    try {
      final restored = await _studio.restore(ProjectStorageKey(key));
      if (restored && mounted) {
        setState(() => _lastProjectKey = key);
        debugLog.info('project_restore', 'Last project restored', {
          'key': key,
          'revision': _studio.revision,
          'name': _studio.project.name,
        });
      } else if (mounted) {
        debugLog.warning('project_restore', 'No stored project for last key', {
          'key': key,
        });
      }
    } on ArgumentError {
      debugLog.warning('project_restore', 'Stored project key is malformed', {
        'key': key,
      });
    }
  }

  Future<void> _restoreWorkspace() async {
    final prefs = await WorkspacePreferences.load();
    if (!mounted) return;
    setState(() {
      _showInspector = prefs.inspectorVisible;
      _canvasFirst = prefs.canvasFirst;
      _inspectorDock = prefs.inspectorDock == 'left'
          ? InspectorDock.left
          : InspectorDock.right;
      _topActionOrder = _sanitizeActionOrder(prefs.topActionOrder);
      _topActionPinned = _sanitizePinned(prefs.topActionPinned);
      // Empty stored config means "never customized": keep the built-in
      // orientation-aware defaults (portrait corners / landscape sides).
      // The current cluster format wins; the retired region format
      // migrates on first load (and is removed on next save).
      final hasStoredClusters = prefs.fullscreenClusters.isNotEmpty;
      final hasLegacyRegions = prefs.fullscreenRegions.isNotEmpty;
      _fullscreenLayoutIsDefault = !hasStoredClusters && !hasLegacyRegions;
      _fullscreenLayout = hasStoredClusters
          ? CanvasControlLayout.fromPrefs(prefs.fullscreenClusters)
          : hasLegacyRegions
          ? CanvasControlLayout.fromLegacyRegions(prefs.fullscreenRegions)
          : CanvasControlLayout.defaults();
    });
    debugLog.info('workspace_restore', 'Workspace preferences restored', {
      'inspector_visible': _showInspector,
      'canvas_first': _canvasFirst,
      'inspector_dock': _inspectorDock.name,
      'top_action_pinned': _topActionPinned.length,
      'fullscreen_clusters': _fullscreenLayout.clusters.length,
    });
  }

  /// Accepts only known action ids, keeps the configured relative order and
  /// fills in any missing actions at the end (canonical order).
  List<EditorTopAction> _sanitizeActionOrder(List<String> raw) {
    final known = <String>{for (final a in EditorTopAction.values) a.name};
    final result = <EditorTopAction>[];
    final seen = <EditorTopAction>{};
    for (final id in raw) {
      if (!known.contains(id)) continue;
      final action = EditorTopAction.values.byName(id);
      if (seen.add(action)) result.add(action);
    }
    for (final action in EditorTopAction.values) {
      if (seen.add(action)) result.add(action);
    }
    return result;
  }

  Set<EditorTopAction> _sanitizePinned(List<String> raw) {
    final known = <String>{for (final a in EditorTopAction.values) a.name};
    final result = <EditorTopAction>{};
    for (final id in raw) {
      if (!known.contains(id)) continue;
      result.add(EditorTopAction.values.byName(id));
    }
    return result;
  }

  /// Pinned actions in the user's configured order (pins not in the order
  /// list are appended at the end of the bar).
  List<EditorTopAction> get _pinnedInOrder => <EditorTopAction>[
    for (final action in _topActionOrder)
      if (_topActionPinned.contains(action)) action,
    for (final action in _topActionPinned)
      if (!_topActionOrder.contains(action)) action,
  ];

  /// True when exactly the selected node is a text frame; enables the
  /// Columns action on the compact and landscape bars.
  bool get _columnsEnabled =>
      _studio.selectedNodeId != null &&
      _studio.project.artboards.isNotEmpty &&
      _studio.project.artboards.first.nodes.any(
        (n) =>
            n.id == _studio.selectedNodeId &&
            n.kind == DocumentNodeKind.textFrame,
      );

  Future<void> _persistWorkspace() => WorkspacePreferences(
    inspectorVisible: _showInspector,
    canvasFirst: _canvasFirst,
    inspectorDock: _inspectorDock.name,
    lastProjectKey: _lastProjectKey,
    topActionOrder: <String>[for (final a in _topActionOrder) a.name],
    topActionPinned: <String>[
      for (final a in _topActionOrder)
        if (_topActionPinned.contains(a)) a.name,
    ],
    fullscreenClusters: _fullscreenLayoutIsDefault
        ? const <String, dynamic>{}
        : _fullscreenLayout.toPrefs(),
  ).save();

  /// Sentinel menu value for the customizer's "New group" option. Generated
  /// cluster ids are `groupN`, so this can never collide.
  static const String _newClusterSentinel = '__new__';

  /// Human-friendly display name for a cluster id.
  String _clusterLabel(String id) => switch (id) {
    'document' => 'Document actions',
    'history' => 'History & zoom',
    'tools' => 'Tools',
    _ => id,
  };

  /// Opens the fullscreen control customization sheet: every
  /// [CanvasControl] with a cluster picker (existing groups + Hidden + New
  /// group), a reset button, and immediate persistence. Cluster POSITIONS
  /// are not edited here — in fullscreen the user long-presses any cluster
  /// and drags it freely, which is the direct manipulation the sheet's
  /// text describes.
  Future<void> _openFullscreenCustomizer() async {
    // Materialize the currently rendered orientation-aware defaults so the
    // sheet edits (and persists) exactly what the user is looking at.
    if (_fullscreenLayoutIsDefault) {
      setState(() {
        _fullscreenLayout = CanvasControlLayout.defaults(
          landscape:
              MediaQuery.of(context).orientation == Orientation.landscape,
        );
        _fullscreenLayoutIsDefault = false;
      });
    }
    debugLog.info(
      'fullscreen_customize',
      'Fullscreen customizer opened',
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          String? clusterOf(CanvasControl control) =>
              _fullscreenLayout.clusterOf(control);

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Customize fullscreen controls',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              setState(() {
                                _fullscreenLayout = CanvasControlLayout
                                    .defaults(
                                      landscape:
                                          MediaQuery.of(context).orientation ==
                                          Orientation.landscape,
                                    );
                                // Back to "never customized": the built-in
                                // orientation-aware defaults take over
                                // again (persisted as an empty config).
                                _fullscreenLayoutIsDefault = true;
                              });
                              unawaited(_persistWorkspace());
                            });
                            debugLog.info(
                              'fullscreen_customize_reset',
                              'Fullscreen controls reset to defaults',
                            );
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Choose which floating group each control belongs to. '
                      'In fullscreen, long-press a group and drag it '
                      'anywhere on the canvas — the position is saved.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final control in CanvasControl.values)
                          ListTile(
                            dense: true,
                            leading: Icon(control.icon),
                            title: Text(control.label),
                            trailing: PopupMenuButton<String?>(
                              initialValue: clusterOf(control),
                              onSelected: (target) {
                                setSheetState(
                                  () => _assignFullscreenControl(
                                    control,
                                    target,
                                    sheetContext,
                                  ),
                                );
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem<String?>(
                                  value: null,
                                  child: Text('Hidden'),
                                ),
                                for (final cluster
                                    in _fullscreenLayout.clusters)
                                  PopupMenuItem<String?>(
                                    value: cluster.id,
                                    child: Text(_clusterLabel(cluster.id)),
                                  ),
                                const PopupMenuItem<String?>(
                                  value: _newClusterSentinel,
                                  child: Text('New group…'),
                                ),
                              ],
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    clusterOf(control) == null
                                        ? 'Hidden'
                                        : _clusterLabel(clusterOf(control)!),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Applies one control placement from the customizer: removes the control
  /// from any cluster, optionally appends it to the chosen cluster (or a
  /// fresh one for "New group"), enforces the per-cluster capacity, and
  /// persists. The immersive exit control can never be hidden (the user
  /// must always be able to leave fullscreen).
  void _assignFullscreenControl(
    CanvasControl control,
    String? target,
    BuildContext sheetContext,
  ) {
    if (control == CanvasControl.immersive && target == null) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          content: Text('The immersive exit control cannot be hidden'),
        ),
      );
      return;
    }
    if (target == _newClusterSentinel) {
      final id = _fullscreenLayout.nextClusterId();
      setState(
        () =>
            _fullscreenLayout = _fullscreenLayout.assignControl(control, id),
      );
      unawaited(_persistWorkspace());
      debugLog.info(
        'fullscreen_control_place',
        'Fullscreen control placed in a new group',
        {'control': control.name, 'cluster': id},
      );
      return;
    }
    if (target != null) {
      final existing = _fullscreenLayout.clusterById(target);
      if (existing != null &&
          existing.controls.length >=
              CanvasControlLayout.maxControlsPerCluster &&
          !existing.controls.contains(control)) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(
            content: Text(
              '${_clusterLabel(target)} is full '
              '(${CanvasControlLayout.maxControlsPerCluster} max)',
            ),
          ),
        );
        return;
      }
    }
    setState(
      () => _fullscreenLayout = target == null
          ? _fullscreenLayout.removeControl(control)
          : _fullscreenLayout.assignControl(control, target),
    );
    unawaited(_persistWorkspace());
    debugLog.info(
      'fullscreen_control_place',
      'Fullscreen control placement updated',
      {'control': control.name, 'cluster': target ?? 'hidden'},
    );
  }

  /// Resolves the controls of one fullscreen cluster into concrete shell
  /// actions (same enablement rules as the compact bar): undo/redo need
  /// history, multi-select needs the Select tool, Columns needs a selected
  /// text frame. Every enabled action also bumps the idle-activity timer
  /// so interacting with a subdued cluster restores its prominence.
  List<ResolvedControlAction> _resolveFullscreenActions(
    List<CanvasControl> controls,
  ) {
    void log(String event, String message, [Map<String, Object?>? extra]) {
      if (extra == null) {
        debugLog.info(event, message);
      } else {
        debugLog.info(event, message, extra);
      }
    }
    final resolved = [
      for (final control in controls)
        ResolvedControlAction(
          control,
          selected: control == CanvasControl.grid && _showGrid,
          onPressed: switch (control) {
            CanvasControl.undo => _studio.canUndo
                ? () {
                    _studio.undo();
                    log('fullscreen_undo', 'Undo applied', {
                      'revision': _studio.revision,
                    });
                  }
                : null,
            CanvasControl.redo => _studio.canRedo
                ? () {
                    _studio.redo();
                    log('fullscreen_redo', 'Redo applied', {
                      'revision': _studio.revision,
                    });
                  }
                : null,
            CanvasControl.zoomIn => () {
              _zoomController.zoomIn();
              log('fullscreen_zoom_in', 'Zoom in');
            },
            CanvasControl.zoomOut => () {
              _zoomController.zoomOut();
              log('fullscreen_zoom_out', 'Zoom out');
            },
            CanvasControl.zoomFit => () {
              _zoomController.fitToScreen();
              log('fullscreen_zoom_fit', 'Fit to screen');
            },
            CanvasControl.grid => () => _toggleGrid(),
            CanvasControl.layers => () {
              _showLayersSheet();
              log('fullscreen_layers', 'Layers sheet opened');
            },
            CanvasControl.multiSelect => _tool == StudioTool.select
                ? () {
                    setState(() => _multiSelect = !_multiSelect);
                    log(
                      'fullscreen_multi_select',
                      _multiSelect
                          ? 'Multi-select enabled'
                          : 'Multi-select disabled',
                    );
                  }
                : null,
            CanvasControl.columns => _columnsEnabled
                ? () => _showColumnsSheet()
                : null,
            CanvasControl.newProject =>
              () => unawaited(_runTopAction(EditorTopAction.newProject)),
            CanvasControl.openProject => () => unawaited(_openProjectSheet()),
            CanvasControl.save =>
              () => unawaited(_runTopAction(EditorTopAction.save)),
            CanvasControl.diagnostics => () => unawaited(
              _runTopAction(EditorTopAction.diagnostics),
            ),
            CanvasControl.settings => () => unawaited(
              _openWorkspaceSettings(),
            ),
            CanvasControl.immersive => () => _setImmersive(false),
            CanvasControl.dockInspector => () => unawaited(
              _runTopAction(EditorTopAction.dockInspector),
            ),
          },
        ),
    ];
    return [
      for (final action in resolved)
        action.onPressed == null
            ? action
            : ResolvedControlAction(
                action.control,
                selected: action.selected,
                onPressed: () {
                  _bumpFullscreenActivity();
                  action.onPressed!();
                },
              ),
    ];
  }

  /// Safe (cutout + gesture) edges the fullscreen clusters clamp into. The
  /// canvas/background may draw edge-to-edge underneath system areas in
  /// immersive mode, but interactive controls must stay fully reachable, so
  /// clusters never render inside the view-padding insets.
  EdgeInsets _fullscreenSafeEdges() {
    final pad = MediaQuery.viewPaddingOf(context);
    double atLeast8(double v) => v < 8 ? 8 : v;
    return EdgeInsets.fromLTRB(
      atLeast8(pad.left),
      atLeast8(pad.top),
      atLeast8(pad.right),
      atLeast8(pad.bottom),
    );
  }

  /// The layout actually rendered in fullscreen. While the user has never
  /// customized placement ([_fullscreenLayoutIsDefault]) the built-in
  /// defaults are derived per orientation — portrait keeps the familiar
  /// corner arrangement, landscape uses left/right side clusters so the
  /// center stays maximum canvas. Customized layouts render as stored;
  /// their normalized positions re-clamp to any viewport at render time.
  CanvasControlLayout _effectiveFullscreenLayout(BoxConstraints constraints) {
    if (!_fullscreenLayoutIsDefault) return _fullscreenLayout;
    return CanvasControlLayout.defaults(
      landscape: constraints.maxWidth > constraints.maxHeight,
    );
  }

  /// Builds one free-form fullscreen control cluster: positioned from its
  /// persisted normalized position (clamped into the safe viewport),
  /// draggable anywhere with no snapping, always rendered even when it
  /// overlaps another cluster, and visually subdued after
  /// [kFullscreenIdleTimeout] of inactivity.
  ///
  /// Dragging is an in-place long-press gesture (no overlay feedback, no
  /// arena fight with the buttons): hold the cluster until the long press
  /// fires, then move — the cluster follows the pointer 1:1 and is clamped
  /// only at the safe-viewport boundary. The cluster's buttons use manual
  /// tooltips so the drag owns every long press deterministically (their
  /// semantics labels keep accessibility intact); taps still execute
  /// normally.
  Widget _freeCluster(
    FullscreenControlCluster cluster,
    BoxConstraints constraints,
    CanvasControlLayout layout,
  ) {
    final safe = _fullscreenSafeEdges();
    final viewport = constraints.biggest;
    final clusterSize = estimatedClusterSize(
      cluster.controls.length,
      dragHandle: true,
    );
    // If the cluster is wider than the safe viewport it scrolls internally;
    // the layout math must use the capped size so clamping stays exact.
    final cappedSize = Size(
      math.min(clusterSize.width, math.max(0.0, viewport.width - safe.horizontal)),
      clusterSize.height,
    );
    Offset pixelPosition() => CanvasControlLayout.clusterPixelsForNormalized(
      cluster.position,
      cappedSize,
      viewport,
      safe,
    );
    final dragging = _clusterDrag?.id == cluster.id;
    final clusterWidget = CanvasControlCluster(
      actions: _resolveFullscreenActions(cluster.controls),
      maxWidth: constraints.maxWidth - 16,
      // The drag IS the cluster's long press: manual tooltips keep the
      // gesture arena deterministic (no competing long-press recognizer).
      tooltipTriggerMode: TooltipTriggerMode.manual,
      showDragHandle: true,
      ignoreControlPresses: dragging,
      onHandlePanStart: (details) => _startClusterDrag(
        cluster,
        layout,
        cappedSize,
        viewport,
        safe,
        details.globalPosition,
      ),
      onHandlePanUpdate: (details) =>
          _updateClusterDrag(details.globalPosition),
      onHandlePanEnd: (_) => _endClusterDrag(canceled: false),
      onHandlePanCancel: () => _endClusterDrag(canceled: true),
    );
    return Positioned(
      // Identity key: bringClusterToFront reorders the Stack children while
      // a drag may be ACTIVE — without a key the dragged element would be
      // reparented to another cluster mid-gesture and the drag would die.
      key: ValueKey('fullscreen_cluster_positioned_${cluster.id}'),
      left: pixelPosition().dx,
      top: pixelPosition().dy,
      child: AnimatedOpacity(
        key: ValueKey('fullscreen_cluster_${cluster.id}'),
        opacity: _fullscreenIdle && !dragging ? kFullscreenIdleOpacity : 1,
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) => _startClusterDrag(
            cluster,
            layout,
            cappedSize,
            viewport,
            safe,
            details.globalPosition,
          ),
          onLongPressMoveUpdate: (details) =>
              _updateClusterDrag(details.globalPosition),
          onLongPressEnd: (_) => _endClusterDrag(canceled: false),
          onLongPressCancel: () => _endClusterDrag(canceled: true),
          child: clusterWidget,
        ),
      ),
    );
  }

  /// Begins a free-form cluster drag at the long-press point. When the
  /// currently rendered layout is still the built-in default, it is
  /// materialized into real user state first so the drag (and everything
  /// after it) edits exactly what the user is looking at.
  void _startClusterDrag(
    FullscreenControlCluster cluster,
    CanvasControlLayout layout,
    Size clusterSize,
    Size viewport,
    EdgeInsets safe,
    Offset globalPosition,
  ) {
    if (_clusterDrag != null) return;
    final stackBox = _fullscreenStackKey.currentContext?.findRenderObject();
    if (stackBox is! RenderBox) return;
    if (_fullscreenLayoutIsDefault) {
      _fullscreenLayout = layout;
      _fullscreenLayoutIsDefault = false;
    }
    final startTopLeft = CanvasControlLayout.clusterPixelsForNormalized(
      cluster.position,
      clusterSize,
      viewport,
      safe,
    );
    _clusterDrag = _ClusterDragSession(
      id: cluster.id,
      startPosition: cluster.position,
      startTopLeft: startTopLeft,
      pointerStartLocal: stackBox.globalToLocal(globalPosition),
      clusterSize: clusterSize,
      viewport: viewport,
      safe: safe,
      stackBox: stackBox,
    );
    _bumpFullscreenActivity();
    setState(
      () => _fullscreenLayout = _fullscreenLayout.bringClusterToFront(
        cluster.id,
      ),
    );
    debugLog.info(
      'cluster_drag_start',
      'Fullscreen control cluster drag started',
      {
        'cluster': cluster.id,
        'x': cluster.position.dx,
        'y': cluster.position.dy,
        'controls': cluster.controls.length,
      },
    );
  }

  /// Moves the dragged cluster 1:1 with the pointer, clamped ONLY into the
  /// safe viewport. No snapping, no nearest-region math, no collision
  /// relocation.
  void _updateClusterDrag(Offset globalPosition) {
    final drag = _clusterDrag;
    if (drag == null) return;
    final pointerLocal = drag.stackBox.globalToLocal(globalPosition);
    final topLeft = drag.startTopLeft + (pointerLocal - drag.pointerStartLocal);
    final normalized = CanvasControlLayout.normalizedForClusterPixels(
      topLeft,
      drag.clusterSize,
      drag.viewport,
      drag.safe,
    );
    final clamped = normalized.dx <= 0 ||
        normalized.dx >= 1 ||
        normalized.dy <= 0 ||
        normalized.dy >= 1;
    setState(
      () => _fullscreenLayout = _fullscreenLayout.moveCluster(
        drag.id,
        normalized,
      ),
    );
    final now = DateTime.now();
    final shouldLog = _lastClusterDragUpdateLog == null ||
        now.difference(_lastClusterDragUpdateLog!) >=
            const Duration(milliseconds: 120);
    if (shouldLog) {
      _lastClusterDragUpdateLog = now;
      debugLog.info(
        'cluster_drag_update',
        'Fullscreen control cluster drag update',
        {
          'cluster': drag.id,
          'x': normalized.dx,
          'y': normalized.dy,
          'clamped': clamped,
        },
      );
      if (clamped) {
        debugLog.info(
          'cluster_clamp',
          'Fullscreen control cluster at safe-viewport bound',
          {'cluster': drag.id, 'x': normalized.dx, 'y': normalized.dy},
        );
      }
    }
  }

  /// Ends the active drag: commits and persists the free-form position, or
  /// restores the drag-start position when the gesture was canceled.
  void _endClusterDrag({required bool canceled}) {
    final drag = _clusterDrag;
    if (drag == null) return;
    _clusterDrag = null;
    setState(() {
      if (canceled) {
        _fullscreenLayout = _fullscreenLayout.moveCluster(
          drag.id,
          drag.startPosition,
        );
        debugLog.info(
          'fullscreen_control_drag_cancel',
          'Fullscreen control cluster drag canceled',
          {'cluster': drag.id},
        );
      } else {
        final cluster = _fullscreenLayout.clusterById(drag.id);
        if (cluster != null) {
          debugLog.info(
            'fullscreen_control_move',
            'Fullscreen control cluster moved',
            {
              'cluster': drag.id,
              'x': cluster.position.dx,
              'y': cluster.position.dy,
              'controls': cluster.controls.length,
            },
          );
        }
      }
    });
    if (!canceled) unawaited(_persistWorkspace());
  }

  /// Opens the workspace settings sheet (moved out of the bottom
  /// navigation into the top-bar More menu per device feedback).
  Future<void> _openWorkspaceSettings() async {
    if (_workspaceSettingsOpen) return;
    _workspaceSettingsOpen = true;
    await _showWorkspaceSettings(
      context,
      canvasFirst: _canvasFirst,
      currentProfile: WorkspaceProfile(
        name: 'Current',
        inspectorVisible: _showInspector,
        canvasFirst: _canvasFirst,
        inspectorDock: _inspectorDock.name,
      ),
      onProfileApplied: (profile) {
        setState(() {
          _showInspector = profile.inspectorVisible;
          _canvasFirst = profile.canvasFirst;
          _inspectorDock = profile.inspectorDock == 'left'
              ? InspectorDock.left
              : InspectorDock.right;
        });
        unawaited(_persistWorkspace());
        debugLog.info(
          'profile_apply',
          'Workspace profile applied',
          {'name': profile.name},
        );
      },
      onCanvasFirstChanged: (value) {
        setState(() => _canvasFirst = value);
        unawaited(_persistWorkspace());
        debugLog.info(
          'canvas_first',
          value ? 'Canvas-first enabled' : 'Canvas-first disabled',
        );
      },
      onReset: () {
        setState(() {
          _showInspector = true;
          _canvasFirst = true;
          _inspectorDock = InspectorDock.right;
        });
        unawaited(
          WorkspacePreferences().clear().then((_) => _persistWorkspace()),
        );
        debugLog.info('workspace_reset', 'Workspace reset to defaults');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workspace reset to defaults')),
          );
        }
      },
    ).whenComplete(() => _workspaceSettingsOpen = false);
  }

  /// Runs a top action-bar action (pinned icon or a More-menu tap).
  Future<void> _runTopAction(EditorTopAction action) async {
    switch (action) {
      case EditorTopAction.openProject:
        await _openProjectSheet();
      case EditorTopAction.newProject:
        await _newProject(context);
      case EditorTopAction.save:
        await _saveProject(context);
      case EditorTopAction.diagnostics:
        await _showDiagnostics(context);
      case EditorTopAction.immersive:
        _setImmersive(!_immersive);
      case EditorTopAction.settings:
        await _openWorkspaceSettings();
      case EditorTopAction.dockInspector:
        setState(() {
          if (_showInspector) {
            _inspectorDock = _inspectorDock == InspectorDock.left
                ? InspectorDock.right
                : InspectorDock.left;
          } else {
            _showInspector = true;
          }
        });
        unawaited(_persistWorkspace());
        debugLog.info(
          'panel_dock',
          'Inspector dock changed',
          {'dock': _inspectorDock.name},
        );
    }
  }

  /// Shows the More menu: every top action in configurable order.
  ///
  /// Normal state shows actions only — no reorder affordances take up
  /// space. Press-and-hold a row to enter reorder mode for that row: the
  /// drag handle and up/down arrows appear, dragging/arrows reorder,
  /// release or any outside interaction returns the menu to normal.
  /// Tapping a row (outside reorder mode) runs the action.
  Future<void> _showMoreMenu() async {
    debugLog.info('top_action_more', 'More menu opened');
    int? reorderIndex;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void exitReorder() {
            if (reorderIndex != null) setSheetState(() => reorderIndex = null);
          }

          void moveRow(int from, int to) {
            final action = _topActionOrder.removeAt(from);
            _topActionOrder.insert(to, action);
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'More actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: const Text('Customize fullscreen controls'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_openFullscreenCustomizer());
                  },
                ),
                const Divider(height: 8),
                Flexible(
                  child: ReorderableListView(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 16),
                    onReorderItem: (oldIndex, newIndex) {
                      setSheetState(() {
                        moveRow(oldIndex, newIndex);
                        reorderIndex = null;
                      });
                      setState(() {}); // shell: the bar reflects immediately
                      debugLog.info(
                        'top_action_reorder',
                        'Action reordered via drag',
                        {
                          'action': _topActionOrder[newIndex].name,
                          'from': oldIndex,
                          'to': newIndex,
                        },
                      );
                      unawaited(_persistWorkspace());
                    },
                    onReorderEnd: (_) => exitReorder(),
                    children: [
                      for (var i = 0; i < _topActionOrder.length; i++)
                        _buildMoreRow(
                          sheetContext: sheetContext,
                          index: i,
                          reorderMode: reorderIndex == i,
                          reorderActive: reorderIndex != null,
                          setSheetState: setSheetState,
                          onEnterReorder: () =>
                              setSheetState(() => reorderIndex = i),
                          onExitReorder: exitReorder,
                          onMoveUp: i == 0
                              ? null
                              : () {
                                  setSheetState(() => moveRow(i, i - 1));
                                  setState(() {});
                                  debugLog.info(
                                    'top_action_reorder',
                                    'Action moved up',
                                    {'action': _topActionOrder[i - 1].name},
                                  );
                                  unawaited(_persistWorkspace());
                                },
                          onMoveDown:
                              i == _topActionOrder.length - 1
                              ? null
                              : () {
                                  setSheetState(() => moveRow(i, i + 1));
                                  setState(() {});
                                  debugLog.info(
                                    'top_action_reorder',
                                    'Action moved down',
                                    {'action': _topActionOrder[i + 1].name},
                                  );
                                  unawaited(_persistWorkspace());
                                },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoreRow({
    required BuildContext sheetContext,
    required int index,
    required bool reorderMode,
    required bool reorderActive,
    required StateSetter setSheetState,
    required VoidCallback onEnterReorder,
    required VoidCallback onExitReorder,
    required VoidCallback? onMoveUp,
    required VoidCallback? onMoveDown,
  }) {
    final action = _topActionOrder[index];
    final pinned = _topActionPinned.contains(action);
    return ListTile(
      key: ValueKey(action.name),
      dense: true,
      leading: IconButton(
        tooltip: pinned ? 'Hide from top bar' : 'Show in top bar',
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          onExitReorder();
          setSheetState(() {
            if (pinned) {
              _topActionPinned.remove(action);
            } else {
              _topActionPinned.add(action);
            }
          });
          setState(() {}); // shell: the bar must reflect the pin immediately
          debugLog.info(
            pinned ? 'top_action_unpin' : 'top_action_pin',
            pinned ? 'Action hidden from top bar' : 'Action pinned to top bar',
            {'action': action.name},
          );
          unawaited(_persistWorkspace());
        },
        icon: Icon(
          pinned ? Icons.star : Icons.star_border,
          color: pinned ? Colors.amber.shade300 : Colors.white54,
        ),
      ),
      title: Text(action.label),
      // Press-and-hold enters reorder mode; a normal tap runs the action.
      // While ANY row is in reorder mode, tapping anywhere only leaves
      // reorder mode — it never accidentally executes an action.
      onTap: () {
        if (reorderActive) {
          onExitReorder();
          return;
        }
        debugLog.info('top_action_run', 'Action run from More menu', {
          'action': action.name,
        });
        Navigator.pop(sheetContext);
        unawaited(_runTopAction(action));
      },
      onLongPress: onEnterReorder,
      trailing: !reorderMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Move down',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                ),
                // Drag handle: the only direct-drag entry point, visible
                // exclusively in reorder mode.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 22,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _setImmersive(bool value) {
    setState(() {
      _immersive = value;
      if (!value) _fullscreenIdle = false;
    });
    if (value) {
      _bumpFullscreenActivity();
    } else {
      _fullscreenIdleTimer?.cancel();
    }
    // Hide the system bars in fullscreen so the canvas reaches the true
    // physical display edges. In immersive the canvas deliberately draws
    // underneath the (hidden) status-bar and cutout area — only the
    // floating controls clamp into the safe insets. Restoring returns to
    // normal edge-to-edge with bars visible; the SafeArea below guards the
    // canvas from insets whenever the bars remain visible.
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
    final padding = MediaQuery.paddingOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    debugLog.info(
      'immersive_mode',
      value ? 'Canvas chrome hidden' : 'Canvas chrome restored',
      {
        'padding_top': padding.top.round(),
        'padding_bottom': padding.bottom.round(),
        'view_padding_top': viewPadding.top.round(),
        'view_padding_bottom': viewPadding.bottom.round(),
      },
    );
  }

  /// Marks fullscreen-control activity: restores full prominence and
  /// (re)arms the idle timer that later fades the controls in place.
  void _bumpFullscreenActivity() {
    if (!mounted || !_immersive) return;
    _fullscreenIdleTimer?.cancel();
    _fullscreenIdleTimer = Timer(kFullscreenIdleTimeout, () {
      if (mounted && _immersive) {
        setState(() => _fullscreenIdle = true);
        debugLog.info(
          'cluster_idle_fade',
          'Fullscreen control clusters faded in place',
          {'opacity': kFullscreenIdleOpacity},
        );
      }
    });
    if (_fullscreenIdle) setState(() => _fullscreenIdle = false);
  }

  /// Opens the compact mobile column-configuration sheet for the selected
  /// text frame (471px-class viewports have no side inspector). Column count,
  /// gutter, reset and live canvas guides all apply through one undoable
  /// controller action per Apply.
  Future<void> _showColumnsSheet() async {
    final selected = _studio.selectedNodeId;
    if (selected == null) return;
    final node = _studio.project.artboards.first.nodes
        .firstWhere((n) => n.id == selected);
    if (node.kind != DocumentNodeKind.textFrame) return;
    debugLog.info(
      'columns_sheet',
      'Column sheet opened',
      {'columns': textNodeColumnCount(node)},
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ColumnsSheet(
        controller: _studio,
        selectedId: selected,
        initialColumns: textNodeColumnCount(node),
        initialGutter: textNodeGutter(node),
        onLiveConfigure: (columns, gutter) {
          // Live preview so column guides update on the canvas.
          _studio.configureTextColumns(
            selected,
            columnCount: columns,
            gutter: gutter,
          );
        },
        onReset: () => _studio.resetTextColumns(selected),
        onApply: (columns, gutter) {
          try {
            _studio.configureTextColumns(
              selected,
              columnCount: columns,
              gutter: gutter,
            );
            return true;
          } on ArgumentError {
            return false;
          }
        },
      ),
    );
  }

  /// Opens the layer list as a bottom sheet on compact phones. Selection
  /// taps sync with the controller so the canvas highlights the chosen node.
  void _showLayersSheet() {
    debugLog.info('layers_sheet', 'Layers sheet opened');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        builder: (context, scrollController) => LayerPanel(
          controller: _studio,
          onNodeSelected: (nodeId) {
            _studio.selectNode(nodeId);
            debugLog.info(
              'layer_select',
              'Node selected from layer sheet',
              {'node_id': nodeId.value},
            );
          },
          onGroup: (count) => debugLog.info(
            'group_create',
            'Group created from selection',
            {'count': count},
          ),
          onUngroup: (groupId) => debugLog.info(
            'group_ungroup',
            'Group dissolved',
            {'node_id': groupId.value},
          ),
        ),
      ),
    );
  }

  Future<void> _newProject(BuildContext context) async {
    var name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New project'),
        content: TextField(
          autofocus: true,
          maxLength: 80,
          onChanged: (value) => name = value,
          decoration: const InputDecoration(labelText: 'Project name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final trimmed = (result ?? name).trim();
    if (!mounted || trimmed.isEmpty) return;
    // Default canvas is portrait and follows the device screen ratio
    // (clamped to a sensible 1:1 .. 9:20 range), per device feedback:
    // "a portrait canvas sized to the display resolution".
    final screen = MediaQuery.sizeOf(context);
    final ratio = (screen.height / screen.width).clamp(1.0, 2.22);
    final artboardWidth = StudioController.defaultArtboardWidth;
    final artboardHeight =
        (artboardWidth * ratio).clamp(
              StudioController.defaultArtboardHeight,
              artboardWidth * 2.4,
            )
            .roundToDouble();
    _studio.newProject(
      trimmed,
      artboardWidth: artboardWidth,
      artboardHeight: artboardHeight,
    );
    debugLog.info(
      'project_new',
      'New project created',
      {'name': trimmed, 'artboard': '${artboardWidth.round()}x${artboardHeight.round()}'},
    );
  }

  Future<void> _saveProject(BuildContext context) async {
    try {
      final receipt = await _studio.save();
      debugLog.info('project_save', 'Project persisted through store', {
        'key': receipt.key.value,
        'revision': receipt.committedRevision,
        'bytes': receipt.byteSize,
        'sha256': receipt.contentSha256,
      });
      // Persist through the shared workspace save so the last-project key,
      // action order/pins and fullscreen layout all stay consistent — no
      // preference is dropped by saving a project.
      setState(() => _lastProjectKey = receipt.key.value);
      await _persistWorkspace();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved r${receipt.committedRevision} — ${receipt.byteSize} bytes '
            '(${receipt.contentSha256.substring(0, 12)}…)',
          ),
        ),
      );
    } on StateError catch (error) {
      debugLog.error('project_save', 'Save rejected by the store', {
        'error': error.toString(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save rejected: ${error.message}')),
      );
    }
  }

  String _formatSavedDate(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// Opens the saved-projects sheet: every project the backing store
  /// currently holds, most recently updated first, with name, revision,
  /// storage key and save time. Tapping an entry opens it. Listing is
  /// fail-closed — a listing failure or an empty store shows a friendly
  /// empty state instead of crashing.
  Future<void> _openProjectSheet() async {
    debugLog.info('project_open_sheet', 'Open project sheet opened');
    List<SavedProjectSummary> summaries;
    try {
      summaries = await _studio.listSavedProjects();
    } catch (error) {
      summaries = const <SavedProjectSummary>[];
      debugLog.warning('project_open_sheet', 'Listing saved projects failed', {
        'error': error.toString(),
      });
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: summaries.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved projects yet. Save a project first, then it '
                  'appears here.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      'Open project',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  for (final summary in summaries)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.folder_open_outlined),
                      title: Text(summary.name),
                      subtitle: Text(
                        'rev ${summary.revision} · ${summary.key} · '
                        '${_formatSavedDate(summary.updatedAt)}',
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        unawaited(_openSavedProject(summary));
                      },
                    ),
                ],
              ),
      ),
    );
  }

  /// Opens one saved project through the EXISTING store restore path (the
  /// same mechanism startup restore uses — no second persistence system).
  /// A missing/corrupt/malformed project fails safe: the current workspace
  /// is left untouched and the condition is recorded in diagnostics.
  Future<void> _openSavedProject(SavedProjectSummary summary) async {
    // Captured up front: never touch a BuildContext after an async gap.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final restored = await _studio.restore(ProjectStorageKey(summary.key));
      if (!mounted) return;
      if (restored) {
        setState(() => _lastProjectKey = summary.key);
        await _persistWorkspace();
        debugLog.info('project_open', 'Project opened', {
          'key': summary.key,
          'name': _studio.project.name,
          'revision': _studio.revision,
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Opened "${summary.name}"')),
        );
      } else {
        debugLog.warning('project_open', 'Project missing or corrupt', {
          'key': summary.key,
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Project missing or corrupt — nothing opened'),
          ),
        );
      }
    } on ArgumentError catch (error) {
      debugLog.warning('project_open', 'Stored project key is malformed', {
        'key': summary.key,
        'error': error.toString(),
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Project key is malformed — nothing opened')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _studio,
      builder: (context, _) {
        // Device class comes from the FULL screen size (MediaQuery), not
        // the body constraints: the body excludes the bottom bar, so
        // classifying from it would misclassify e.g. 800×600 as compact.
        final cls = classifyWorkspace(
          MediaQuery.sizeOf(context).width,
          MediaQuery.sizeOf(context).height,
        );
        return Scaffold(
          appBar: null,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final compact = cls != WorkspaceClass.wide;
              _recordLayout(
                _immersive
                    ? 'immersive_canvas'
                    : cls == WorkspaceClass.compactLandscape
                    ? 'compact_landscape'
                    : compact
                    ? 'compact_bottom_navigation'
                    : 'wide_rail_navigation',
                MediaQuery.sizeOf(context),
              );
              final showPanels = !_immersive;
              final inspector =
                  showPanels && _showInspector && constraints.maxWidth >= 900
                  ? SizedBox(
                      width: 280,
                      child: InspectorPanel(controller: _studio),
                    )
                  : const SizedBox.shrink();
              return SafeArea(
                // NORMAL mode: the canvas must NEVER draw under the status
                // bar (device feedback: the canvas and zoomed content slid
                // under the status bar), so the top inset is consumed here.
                // IMMERSIVE mode: the canvas deliberately uses the FULL
                // physical display area — device feedback reported an unused
                // status-bar-height strip left above the canvas. The top
                // inset is therefore NOT consumed in immersive; the system
                // bars are hidden and the canvas/background extends behind
                // the status-bar/cutout region, while the floating control
                // clusters clamp themselves into the safe insets.
                top: !_immersive,
                bottom: _immersive,
                left: false,
                right: false,
                child: Stack(
                key: _fullscreenStackKey,
                children: [
                  Row(
                    children: [
                      // Canonical mobile workspace: a stable vertical tool
                      // rail on the left (phone portrait) — primary tools
                      // never move between edges.
                      if (showPanels &&
                          (cls == WorkspaceClass.compactPortrait ||
                              cls == WorkspaceClass.compactLandscape))
                        MobileToolRail(
                          activeTool: _tool,
                          onSelected: _selectTool,
                        ),
                      if (showPanels && cls == WorkspaceClass.wide)
                        ToolRail(
                          selectedTool: _tool,
                          onSelected: _selectTool,
                        ),
                      if (showPanels &&
                          cls == WorkspaceClass.wide &&
                          _showInspector &&
                          _inspectorDock == InspectorDock.left)
                        inspector,
                      Expanded(
                        child: CanvasArea(
                          size: constraints.biggest,
                          projectName: _studio.project.name,
                          controller: _studio,
                          drawEnabled: _tool == StudioTool.draw,
                          ellipseEnabled: _tool == StudioTool.ellipse,
                          selectMode: _tool == StudioTool.select,
                          textEnabled: _tool == StudioTool.text,
                          immersive: _immersive,
                          multiSelectMode: _multiSelect,
                          gridVisible: _showGrid,
                          onToggleGrid: _toggleGrid,
                          selectedNodeId: _studio.selectedNodeId,
                          // In immersive the user's chosen control regions
                          // replace the default top bar entirely.
                          hideProjectName: _immersive,
                          topBar: _immersive
                              ? null
                              : _TopActionBar(
                                  actions: _pinnedInOrder,
                                  onRun: (action) => unawaited(
                                    _runTopAction(action),
                                  ),
                                  onMore: () => unawaited(_showMoreMenu()),
                                ),
                          suppressGeometryLog: _workspaceSettingsOpen,
                          zoomController: _zoomController,
                          onNodeAdded: () {
                            debugLog.info(
                              'node_add',
                              'Shape added by Draw tool',
                              {
                                'object_count': _studio.objectCount,
                                'revision': _studio.revision,
                              },
                            );
                          },
                          onNodeSelected: (nodeId, additive) {
                            _studio.selectNode(nodeId, toggle: additive);
                            debugLog.info(
                              nodeId != null ? 'node_select' : 'node_deselect',
                              nodeId != null
                                  ? 'Node selected by Select tool'
                                  : 'Selection cleared',
                              {
                                if (nodeId != null) 'node_id': nodeId.value,
                                'selected_count': _studio.selectedNodeIds.length,
                              },
                            );
                          },
                          onTextRequest: (artboardPoint) {
                            _addTextAt(artboardPoint);
                          },
                          onTwoFingerTap: () {
                            if (!_studio.canUndo) return;
                            _studio.undo();
                            debugLog.info(
                              'gesture_undo',
                              'Two-finger tap undo',
                              {'revision': _studio.revision},
                            );
                          },
                          onThreeFingerTap: () {
                            if (!_studio.canRedo) return;
                            _studio.redo();
                            debugLog.info(
                              'gesture_redo',
                              'Three-finger tap redo',
                              {'revision': _studio.revision},
                            );
                          },
                        ),
                      ),
                      if (showPanels &&
                          cls == WorkspaceClass.wide &&
                          _showInspector &&
                          _inspectorDock == InspectorDock.right)
                        inspector,
                      if (showPanels &&
                          cls == WorkspaceClass.compactLandscape)
                        LandscapeActionRail(
                          controller: _studio,
                          zoomController: _zoomController,
                          activeTool: _tool,
                          gridVisible: _showGrid,
                          onToggleGrid: _toggleGrid,
                          onToggleMultiSelect: () {
                            setState(() => _multiSelect = !_multiSelect);
                            debugLog.info(
                              'multi_select_toggle',
                              _multiSelect
                                  ? 'Multi-select enabled'
                                  : 'Multi-select disabled',
                            );
                          },
                          onShowLayers: () {
                            _showLayersSheet();
                            debugLog.info(
                              'layers_toggle',
                              'Layers via landscape rail',
                            );
                          },
                          multiSelect: _multiSelect,
                          columnsEnabled: _columnsEnabled,
                          onConfigureColumns: _showColumnsSheet,
                          onDiagnostic: (event) =>
                              debugLog.info(event, 'Landscape rail control used'),
                        ),
                      if (showPanels &&
                          cls == WorkspaceClass.wide &&
                          _showLayers)
                        SizedBox(
                          width: 260,
                          child: Card(
                            margin: const EdgeInsets.all(8),
                            child: LayerPanel(
                              controller: _studio,
                              onNodeSelected: (nodeId) {
                                _studio.selectNode(nodeId);
                                debugLog.info(
                                  'layer_select',
                                  'Node selected from layer list',
                                  {'node_id': nodeId.value},
                                );
                              },
                              onGroup: (count) => debugLog.info(
                                'group_create',
                                'Group created from selection',
                                {'count': count},
                              ),
                              onUngroup: (groupId) => debugLog.info(
                                'group_ungroup',
                                'Group dissolved',
                                {'node_id': groupId.value},
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!_immersive && cls == WorkspaceClass.wide)
                    Positioned(
                      bottom: 16,
                      left: 12,
                      child: SafeArea(
                        child: _HistoryBar(
                          canUndo: _studio.canUndo,
                          canRedo: _studio.canRedo,
                          onUndo: () {
                            _studio.undo();
                            debugLog.info('history_undo', 'Undo applied', {
                              'revision': _studio.revision,
                            });
                          },
                          onRedo: () {
                            _studio.redo();
                            debugLog.info('history_redo', 'Redo applied', {
                              'revision': _studio.revision,
                            });
                          },
                        ),
                      ),
                    ),
                  if (!_immersive && cls == WorkspaceClass.wide)
                    Positioned(
                      // Below the overlay top bar (which occupies the very
                      // top of the canvas); a top:12 position collided with
                      // the More button and broke its hit area on
                      // tablet/wide layouts.
                      top: 60,
                      right: 12,
                      child: SafeArea(
                        child: IconButton.filledTonal(
                          tooltip: _showLayers ? 'Hide layers' : 'Show layers',
                          onPressed: () {
                            if (cls != WorkspaceClass.wide) {
                              _showLayersSheet();
                            } else {
                              setState(() => _showLayers = !_showLayers);
                              debugLog.info(
                                'layers_toggle',
                                _showLayers ? 'Layers panel opened' : 'Layers panel closed',
                              );
                            }
                          },
                          icon: Icon(
                            _showLayers && cls == WorkspaceClass.wide
                                ? Icons.layers_clear_outlined
                                : Icons.layers_outlined,
                          ),
                        ),
                      ),
                    ),
                  // Fullscreen control clusters: the user's chosen controls
                  // rendered as free-form floating clusters (normalized
                  // positions, no snapping), replacing the default top bar
                  // and the legacy fixed zoom overlay. All clusters render
                  // even when they overlap; the last-touched one is on top.
                  // Never-customized defaults are orientation-aware:
                  // portrait keeps the corner arrangement, landscape places
                  // the clusters on the LEFT and RIGHT sides.
                  if (_immersive)
                    for (final cluster
                        in _effectiveFullscreenLayout(constraints).clusters)
                      _freeCluster(
                        cluster,
                        constraints,
                        _effectiveFullscreenLayout(constraints),
                      ),
                ],
                ),
              );
            },
          ),
          bottomNavigationBar: (_immersive ||
                  cls == WorkspaceClass.compactLandscape)
              ? null
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (cls == WorkspaceClass.compactPortrait) {
                      // Canonical mobile workspace: ONE bottom surface — the
                      // contextual action bar (history/zoom/view groups plus
                      // state-dependent actions). Primary tools live on the
                      // left rail; there is no second competing toolbar.
                      return ContextualActionBar(
                        controller: _studio,
                        zoomController: _zoomController,
                        activeTool: _tool,
                        gridVisible: _showGrid,
                        multiSelect: _multiSelect,
                        columnsEnabled: _columnsEnabled,
                        onToggleGrid: _toggleGrid,
                        onToggleMultiSelect: () {
                          setState(() => _multiSelect = !_multiSelect);
                          debugLog.info(
                            'multi_select_toggle',
                            _multiSelect
                                ? 'Multi-select enabled'
                                : 'Multi-select disabled',
                          );
                        },
                        onShowLayers: () {
                          _showLayersSheet();
                          debugLog.info('layers_toggle', 'Layers via action bar');
                        },
                        onConfigureColumns: _showColumnsSheet,
                        onDiagnostic: (event) =>
                            debugLog.info(event, 'Action bar control used'),
                      );
                    }
                    return StatusBar(
                      objectCount: _studio.objectCount,
                      revision: _studio.revision,
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Wide-layout tool rail. Renders from the same [StudioTool] metadata as
/// the compact [MobileToolRail], so both surfaces always agree on tool
/// identity, order and icons.
class ToolRail extends StatelessWidget {
  const ToolRail({
    required this.selectedTool,
    required this.onSelected,
    super.key,
  });

  final StudioTool selectedTool;
  final ValueChanged<StudioTool> onSelected;

  @override
  Widget build(BuildContext context) => NavigationRail(
    selectedIndex: selectedTool.index,
    onDestinationSelected: (i) => onSelected(StudioTool.values[i]),
    labelType: NavigationRailLabelType.all,
    destinations: [
      for (final tool in StudioTool.values)
        NavigationRailDestination(
          icon: Icon(tool.icon),
          selectedIcon: Icon(tool.selectedIcon),
          label: Text(tool.label),
        ),
    ],
  );
}

class CanvasArea extends StatelessWidget {
  const CanvasArea({
    required this.size,
    required this.projectName,
    required this.controller,
    required this.drawEnabled,
    required this.onNodeAdded,
    this.ellipseEnabled = false,
    this.selectMode = false,
    this.textEnabled = false,
    this.immersive = false,
    this.multiSelectMode = false,
    this.gridVisible = true,
    this.onToggleGrid,
    this.topBar,
    this.selectedNodeId,
    this.suppressGeometryLog = false,
    this.zoomController,
    this.hideProjectName = false,
    this.onTextRequest,
    this.onNodeSelected,
    this.onTwoFingerTap,
    this.onThreeFingerTap,
    this.onViewportChanged,
    super.key,
  });

  final Size size;
  final String projectName;
  final StudioController controller;
  final bool drawEnabled;
  final bool ellipseEnabled;
  final VoidCallback onNodeAdded;
  final bool selectMode;
  final bool textEnabled;

  /// True in immersive mode: the project-name overlay is hidden so the
  /// user's chosen fullscreen controls are the only chrome.
  final bool hideProjectName;

  /// Whether the shell is in immersive canvas mode; keeps the in-canvas
  /// zoom overlay available there (no bottom toolbar exists in immersive).
  final bool immersive;

  /// Multi-select mode from the shell: Select-tool taps toggle membership.
  final bool multiSelectMode;

  /// Grid overlay state, forwarded to [StudioCanvas]; [onToggleGrid] null
  /// hides the grid button in the canvas overlay (compact phones control the
  /// grid from the bottom toolbar).
  final bool gridVisible;
  final VoidCallback? onToggleGrid;

  /// Transparent top action bar rendered inside the canvas bounds, right
  /// under the status bar ("at the canvas boundary"), so project actions
  /// float over the artwork instead of consuming chrome space.
  final Widget? topBar;

  final GgenId? selectedNodeId;

  /// Suppresses canvas_geometry logging (e.g. while the settings sheet is
  /// open and the canvas is being resized by the sheet animation).
  final bool suppressGeometryLog;

  /// Optional zoom command channel from the shell.
  final CanvasZoomController? zoomController;

  final void Function(Offset artboardPoint)? onTextRequest;
  final void Function(GgenId? nodeId, bool additive)? onNodeSelected;
  final VoidCallback? onTwoFingerTap;
  final VoidCallback? onThreeFingerTap;
  final void Function(CanvasViewport)? onViewportChanged;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xff101217),
    child: Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            recordCanvasGeometry(
              context,
              constraints.biggest,
              suppress: suppressGeometryLog,
            );
            // Compact phones get undo/redo, layers and zoom from the bottom
            // toolbar, so the in-canvas zoom overlay is redundant there.
            // Wide layouts keep it (single source of zoom UI); immersive
            // uses the user's fullscreen control regions instead.
            // Class comes from the full view size, not this local size
            // (which excludes any bottom bar).
            final cls = classifyWorkspace(
              MediaQuery.sizeOf(context).width,
              MediaQuery.sizeOf(context).height,
            );
            return RepaintBoundary(
              child: StudioCanvas(
                controller: controller,
                drawEnabled: drawEnabled,
                ellipseEnabled: ellipseEnabled,
                onNodeAdded: onNodeAdded,
                selectMode: selectMode,
                textEnabled: textEnabled,
                showZoomOverlay: !immersive && cls == WorkspaceClass.wide,
                multiSelectMode: multiSelectMode,
                gridVisible: gridVisible,
                onToggleGrid: onToggleGrid,
                selectedNodeId: selectedNodeId,
                zoomController: zoomController,
                onViewportChanged: onViewportChanged,
                onTextRequest: onTextRequest,
                onNodeSelected: onNodeSelected,
                onTwoFingerTap: onTwoFingerTap,
                onThreeFingerTap: onThreeFingerTap,
              ),
            );
          },
        ),
        // Transparent top action bar (icon-only, inside canvas bounds).
        if (topBar != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: topBar!,
          ),
        // Project name — no hazy bar per device feedback (was black 0.45 scrim).
        // Now a clean text with shadow for legibility, no container bar.
        // Hidden in immersive so the user's controls are the only chrome.
        if (!hideProjectName)
          Positioned(
          top: topBar == null ? 12 : 62,
          left: 12,
          right: 96,
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  projectName,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black54),
                      Shadow(blurRadius: 8, color: Colors.black26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class InspectorPanel extends StatefulWidget {
  const InspectorPanel({required this.controller, super.key});

  final StudioController controller;

  @override
  State<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<InspectorPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(covariant InspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selectedId = controller.selectedNodeId;
    final artboards = controller.project.artboards;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inspector', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (selectedId == null || artboards.isEmpty) ...[
              const Text('Select an object to inspect its properties.'),
              const SizedBox(height: 12),
              Text('Objects: ${controller.objectCount}  •  Rev ${controller.revision}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54)),
            ] else ...[
              // The text-frame inspector (content + columns + text flow) can
              // be taller than a compact window; keep it reachable by
              // scrolling instead of overflowing the panel.
              Expanded(
                child: SingleChildScrollView(
                  child: _InspectorContent(
                    controller: controller,
                    selectedId: selectedId,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InspectorContent extends StatefulWidget {
  const _InspectorContent({required this.controller, required this.selectedId});

  final StudioController controller;
  final GgenId selectedId;

  @override
  State<_InspectorContent> createState() => _InspectorContentState();
}

class _InspectorContentState extends State<_InspectorContent> {
  late TextEditingController _xCtrl;
  late TextEditingController _yCtrl;
  late TextEditingController _wCtrl;
  late TextEditingController _hCtrl;
  late TextEditingController _textCtrl;
  late TextEditingController _sizeCtrl;
  late TextEditingController _gutterCtrl;

  DocumentNode? _node;
  NodeShapeGeometry? _geom;
  TextNodeGeometry? _textGeom;
  int _columns = 1;
  String? _successorId;
  String? _successorName;
  List<DocumentNode> _linkCandidates = const <DocumentNode>[];

  // Shape-style editor state (applied through one undoable controller call).
  int _editFill = 0xFF4E6BFF;
  bool _editHasStroke = false;
  int _editStroke = 0xFF000000;
  double _editStrokeWidth = 2.0;

  static const List<int> _palette = <int>[
    0xFF4E6BFF, 0xFFFF6B6B, 0xFFFFD93D, 0xFF6BCB77,
    0xFFB983FF, 0xFFFF9F68, 0xFF4ECDC4, 0xFFE056FD,
    0xFF000000, 0xFFFFFFFF, 0xFF888888, 0xFF222222,
  ];

  @override
  void initState() {
    super.initState();
    _xCtrl = TextEditingController();
    _yCtrl = TextEditingController();
    _wCtrl = TextEditingController();
    _hCtrl = TextEditingController();
    _textCtrl = TextEditingController();
    _sizeCtrl = TextEditingController();
    _gutterCtrl = TextEditingController(text: '0');
    _syncFromNode();
    widget.controller.addListener(_syncFromNode);
  }

  @override
  void didUpdateWidget(covariant _InspectorContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId || oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromNode);
      widget.controller.addListener(_syncFromNode);
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromNode);
    _xCtrl.dispose();
    _yCtrl.dispose();
    _wCtrl.dispose();
    _hCtrl.dispose();
    _textCtrl.dispose();
    _sizeCtrl.dispose();
    _gutterCtrl.dispose();
    super.dispose();
  }

  void _syncFromNode() {
    final artboards = widget.controller.project.artboards;
    final nodes = artboards.isEmpty ? const <DocumentNode>[] : artboards.first.nodes;
    final idx = nodes.indexWhere((n) => n.id == widget.selectedId);
    if (idx < 0) return;
    final node = nodes[idx];
    // Route by node KIND: text frames (which may now also carry w/h for
    // column geometry) must always use the text inspector, never the shape
    // branch. Shapes use shape geometry; other kinds get neither.
    final isText = node.kind == DocumentNodeKind.textFrame;
    final geom = isText ? null : nodeGeometry(node);
    final tgeom = isText ? textNodeGeometry(node) : null;
    // Always sync from node; field focus handling deferred (numeric inspector is explicit Apply model).
    setState(() {
      _node = node;
      _geom = geom;
      _textGeom = tgeom;
      if (geom != null) {
        _xCtrl.text = geom.x.toStringAsFixed(1);
        _yCtrl.text = geom.y.toStringAsFixed(1);
        _wCtrl.text = geom.width.toStringAsFixed(1);
        _hCtrl.text = geom.height.toStringAsFixed(1);
        _editFill = geom.fill;
        _editHasStroke = geom.hasStroke;
        _editStroke = geom.stroke ?? 0xFF000000;
        _editStrokeWidth = geom.hasStroke ? geom.strokeWidth : 2.0;
      } else if (tgeom != null) {
        final fg = textNodeFrameGeometry(node);
        _xCtrl.text = tgeom.x.toStringAsFixed(1);
        _yCtrl.text = tgeom.y.toStringAsFixed(1);
        _wCtrl.text = fg != null ? fg.frameWidth.toStringAsFixed(1) : '';
        _hCtrl.text = fg != null ? fg.frameHeight.toStringAsFixed(1) : '';
        _textCtrl.text = tgeom.text;
        _sizeCtrl.text = tgeom.size.toStringAsFixed(1);
        _columns = textNodeColumnCount(node);
        _gutterCtrl.text = textNodeGutter(node).toStringAsFixed(1);
        final successorId = textFrameSuccessor(node);
        _successorId = successorId;
        String? name;
        if (successorId != null) {
          final si = nodes.indexWhere((n) => n.id.value == successorId);
          name = si >= 0 ? nodes[si].name : successorId;
        }
        _successorName = name;
        _linkCandidates = artboards.isEmpty
            ? const <DocumentNode>[]
            : linkCandidates(artboards.first, node.id);
      } else {
        _successorId = null;
        _successorName = null;
        _linkCandidates = const <DocumentNode>[];
      }
    });
  }

  void _linkTextFlow(GgenId targetId) {
    try {
      final ok = widget.controller.linkTextFrames(widget.selectedId, targetId);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link rejected — frames not linkable or no change.'),
          ),
        );
        return;
      }
      debugLog.info('inspector_flow_link', 'Inspector linked text frames', {
        'source': widget.selectedId.value,
        'target': targetId.value,
        'revision': widget.controller.revision,
      });
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link rejected: ${e.message}')),
      );
    }
  }

  void _unlinkTextFlow() {
    final ok = widget.controller.unlinkTextFrame(widget.selectedId);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlink rejected — no link to remove.')),
      );
      return;
    }
    debugLog.info(
      'inspector_flow_unlink',
      'Inspector unlinked text frame',
      {'source': widget.selectedId.value, 'revision': widget.controller.revision},
    );
  }

  void _applyColumns() {
    final gutter = double.tryParse(_gutterCtrl.text.trim());
    if (gutter == null || !gutter.isFinite || gutter < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gutter must be a finite number ≥ 0')),
      );
      return;
    }
    try {
      final ok = widget.controller.configureTextColumns(
        widget.selectedId,
        columnCount: _columns,
        gutter: gutter,
      );
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Column change rejected (no change or node not a text frame)')),
        );
      } else {
        debugLog.info('inspector_columns', 'Inspector text columns applied', {
          'columns': _columns,
          'gutter': gutter,
          'revision': widget.controller.revision,
        });
      }
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid columns: ${e.message}')),
      );
    }
  }

  void _resetColumns() {
    setState(() => _columns = 1);
    _gutterCtrl.text = '0.0';
    final ok = widget.controller.resetTextColumns(widget.selectedId);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset rejected — not a text frame')),
      );
    } else {
      debugLog.info('inspector_columns_reset', 'Text columns reset to 1');
    }
  }

  void _applyShapeGeometry() {
    final geom = _geom;
    if (geom == null) return;
    final x = double.tryParse(_xCtrl.text.trim());
    final y = double.tryParse(_yCtrl.text.trim());
    final w = double.tryParse(_wCtrl.text.trim());
    final h = double.tryParse(_hCtrl.text.trim());
    if (x == null || y == null || w == null || h == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid numbers for X/Y/W/H')));
      return;
    }
    if (!x.isFinite || !y.isFinite || !w.isFinite || !h.isFinite || w < 8 || h < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('W/H must be ≥8 and numbers finite')));
      return;
    }
    final ok = widget.controller.resizeNode(widget.selectedId, x: x, y: y, width: w, height: h);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resize failed — node not found or not a shape')));
    } else {
      debugLog.info('inspector_resize', 'Inspector numeric resize', {'x': x, 'y': y, 'w': w, 'h': h});
    }
  }

  void _applyShapeStyle() {
    final ok = widget.controller.updateShapeStyle(
      widget.selectedId,
      fill: _editFill,
      stroke: _editHasStroke ? _editStroke : null,
      strokeWidth: _editStrokeWidth,
      clearStroke: !_editHasStroke,
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Style update failed — node not a shape or no change')),
      );
    } else {
      debugLog.info('inspector_style', 'Inspector shape style applied', {
        'fill': _editFill,
        'stroke': _editHasStroke ? _editStroke : null,
        'stroke_width': _editStrokeWidth,
      });
    }
  }

  void _applyTextProperties() {
    final text = _textCtrl.text.trim();
    final size = double.tryParse(_sizeCtrl.text.trim());
    final x = double.tryParse(_xCtrl.text.trim());
    final y = double.tryParse(_yCtrl.text.trim());
    if (text.isEmpty || text.length > 256) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content must be 1..256 characters')),
      );
      return;
    }
    if (size == null || x == null || y == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid numbers for Size/X/Y')),
      );
      return;
    }
    if (!size.isFinite || size <= 0 || !x.isFinite || !y.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Size must be > 0 and numbers must be finite'),
        ),
      );
      return;
    }
    final ok = widget.controller.updateTextNode(
      widget.selectedId,
      text: text,
      size: size,
      x: x,
      y: y,
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit failed — node not found or nothing changed'),
        ),
      );
    } else {
      debugLog.info('inspector_text_edit', 'Inspector text edit', {
        'text': text,
        'size': size,
        'x': x,
        'y': y,
        'revision': widget.controller.revision,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;
    final geom = _geom;
    final tgeom = _textGeom;
    if (node == null) {
      return const Text('Selected node not found.');
    }
    if (geom != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(node.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Shape • ${geom.width.toStringAsFixed(1)} × ${geom.height.toStringAsFixed(1)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _NumberField(label: 'X', controller: _xCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _NumberField(label: 'Y', controller: _yCtrl)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _NumberField(label: 'W', controller: _wCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _NumberField(label: 'H', controller: _hCtrl)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _applyShapeGeometry,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Apply geometry'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('Fill', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _ColorSwatchRow(
            selected: _editFill,
            colors: _palette,
            onSelected: (c) {
              setState(() => _editFill = c);
              _applyShapeStyle();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Stroke', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch(
                value: _editHasStroke,
                onChanged: (v) {
                  setState(() => _editHasStroke = v);
                  _applyShapeStyle();
                },
              ),
            ],
          ),
          if (_editHasStroke) ...[
            const SizedBox(height: 4),
            _ColorSwatchRow(
              selected: _editStroke,
              colors: _palette,
              onSelected: (c) {
                setState(() => _editStroke = c);
                _applyShapeStyle();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Width'),
                const SizedBox(width: 8),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  onPressed: _editStrokeWidth > 0.5 ? () {
                    setState(() => _editStrokeWidth = (_editStrokeWidth - 1).clamp(0.5, 24));
                    _applyShapeStyle();
                  } : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _editStrokeWidth.toStringAsFixed(1),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  onPressed: _editStrokeWidth < 24 ? () {
                    setState(() => _editStrokeWidth = (_editStrokeWidth + 1).clamp(0.5, 24));
                    _applyShapeStyle();
                  } : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text('Hold Shift for proportional, Ctrl for 8-unit snap on canvas handles.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 11)),
        ],
      );
    }
    if (tgeom != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(node.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Text frame', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('inspector_text_content'),
            controller: _textCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Content',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _NumberField(
                fieldKey: const ValueKey('inspector_text_x'),
                label: 'X',
                controller: _xCtrl,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                fieldKey: const ValueKey('inspector_text_y'),
                label: 'Y',
                controller: _yCtrl,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _NumberField(
            fieldKey: const ValueKey('inspector_text_size'),
            label: 'Size',
            controller: _sizeCtrl,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('inspector_text_apply'),
              onPressed: _applyTextProperties,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Apply'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('Columns', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Count'),
              Expanded(
                child: Slider(
                  key: const ValueKey('inspector_columns_slider'),
                  value: _columns.toDouble(),
                  min: 1,
                  max: StudioController.maxTextFrameColumns.toDouble(),
                  divisions: StudioController.maxTextFrameColumns - 1,
                  label: '$_columns',
                  onChanged: (v) => setState(() => _columns = v.round()),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$_columns',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  fieldKey: const ValueKey('inspector_gutter'),
                  label: 'Gutter',
                  controller: _gutterCtrl,
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                key: const ValueKey('inspector_columns_reset'),
                onPressed: _resetColumns,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('inspector_columns_apply'),
              onPressed: _applyColumns,
              child: const Text('Apply columns'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Columns fill left→right; overflow flows to a linked frame. One undoable step per Apply.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('Text flow', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_successorId != null) ...[
            Text('Flows into: ${_successorName ?? _successorId}'),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('inspector_flow_unlink'),
              onPressed: _unlinkTextFlow,
              child: const Text('Unlink'),
            ),
          ] else if (_linkCandidates.isEmpty)
            Text(
              'No other text frame to link to.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 11),
            )
          else
            for (final candidate in _linkCandidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: OutlinedButton.icon(
                  key: ValueKey('inspector_flow_link_${candidate.id.value}'),
                  onPressed: () => _linkTextFlow(candidate.id),
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(candidate.name),
                ),
              ),
          const SizedBox(height: 8),
          Text('Linking makes overflowing text continue into the next frame. One undoable step per action.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 11)),
        ],
      );
    }
    return Text('Unknown node kind: ${node.kind.name}');
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.controller,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;

  /// Optional key applied to the inner [TextField] (for tests), distinct
  /// from the widget's own key.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) {},
    );
  }
}

Future<void> _showWorkspaceSettings(
  BuildContext context, {
  required bool canvasFirst,
  required WorkspaceProfile currentProfile,
  required ValueChanged<WorkspaceProfile> onProfileApplied,
  required ValueChanged<bool> onCanvasFirstChanged,
  required VoidCallback onReset,
}) async {
  debugLog.info('workspace_settings', 'Workspace settings opened');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.48,
      minChildSize: 0.28,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text('Workspace', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Move or dismiss this sheet at any time. The canvas remains unobstructed until settings are explicitly opened.',
          ),
          const SizedBox(height: 16),
          _CanvasFirstSwitch(
            initial: canvasFirst,
            onChanged: onCanvasFirstChanged,
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('Manage profiles'),
            subtitle: const Text('Save or restore workspace arrangements'),
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (context) => ProfileManagerSheet(
                  current: currentProfile,
                  onApply: onProfileApplied,
                  onEvent: (event) =>
                      debugLog.info(event, 'Workspace profile event'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Reset workspace'),
            subtitle: const Text('Restore the default compact layout'),
            onTap: () {
              debugLog.info('workspace_reset', 'Workspace reset requested');
              onReset();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}

class _CanvasFirstSwitch extends StatefulWidget {
  const _CanvasFirstSwitch({required this.initial, required this.onChanged});

  final bool initial;
  final ValueChanged<bool> onChanged;

  @override
  State<_CanvasFirstSwitch> createState() => _CanvasFirstSwitchState();
}

class _CanvasFirstSwitchState extends State<_CanvasFirstSwitch> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    value: _value,
    onChanged: (value) {
      // The sheet is a captured snapshot of the shell state; keep the
      // switch's own state so taps reflect immediately (device diagnostics
      // exposed a frozen switch when this was driven by the captured param).
      setState(() => _value = value);
      widget.onChanged(value);
    },
    title: const Text('Canvas-first controls'),
    subtitle: const Text('Keep tool controls outside the active canvas'),
  );
}

/// Compact mobile column-configuration sheet (471px-class viewports have no
/// side inspector). Owns its gutter [TextEditingController] so the controller
/// outlives the sheet's exit animation.
class _ColumnsSheet extends StatefulWidget {
  const _ColumnsSheet({
    required this.controller,
    required this.selectedId,
    required this.initialColumns,
    required this.initialGutter,
    required this.onLiveConfigure,
    required this.onReset,
    required this.onApply,
  });

  /// The sheet live-observes the controller so the Text flow section
  /// (link/unlink) reflects the project without reopening.
  final StudioController controller;
  final GgenId selectedId;
  final int initialColumns;
  final double initialGutter;
  final void Function(int columns, double gutter) onLiveConfigure;
  final VoidCallback onReset;
  final bool Function(int columns, double gutter) onApply;

  @override
  State<_ColumnsSheet> createState() => _ColumnsSheetState();
}

class _ColumnsSheetState extends State<_ColumnsSheet> {
  late final TextEditingController _gutterCtrl = TextEditingController(
    text: widget.initialGutter.toStringAsFixed(1),
  );
  late int _columns = widget.initialColumns;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _gutterCtrl.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  void _link(GgenId targetId) {
    try {
      final ok =
          widget.controller.linkTextFrames(widget.selectedId, targetId);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link rejected — frames not linkable or no change.'),
          ),
        );
      }
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link rejected: ${e.message}')),
      );
    }
  }

  void _unlink() {
    final ok = widget.controller.unlinkTextFrame(widget.selectedId);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlink rejected — no link to remove.')),
      );
    }
  }

  void _liveConfigure() {
    final g = double.tryParse(_gutterCtrl.text.trim()) ?? 0;
    if (g.isFinite && g >= 0) {
      widget.onLiveConfigure(_columns, g);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Text columns',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Count'),
              Expanded(
                child: Slider(
                  key: const ValueKey('mobile_columns_slider'),
                  value: _columns.toDouble(),
                  min: 1,
                  max: StudioController.maxTextFrameColumns.toDouble(),
                  divisions: StudioController.maxTextFrameColumns - 1,
                  label: '$_columns',
                  onChanged: (v) {
                    setState(() => _columns = v.round());
                    _liveConfigure();
                  },
                ),
              ),
              SizedBox(width: 32, child: Text('$_columns')),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('mobile_gutter_field'),
                  controller: _gutterCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _liveConfigure(),
                  decoration: const InputDecoration(
                    labelText: 'Gutter',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const ValueKey('mobile_columns_reset'),
                onPressed: () {
                  setState(() => _columns = 1);
                  _gutterCtrl.text = '0.0';
                  widget.onReset();
                },
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('mobile_columns_apply'),
                onPressed: () {
                  final g = double.tryParse(_gutterCtrl.text.trim());
                  if (g == null || !g.isFinite || g < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gutter must be finite and ≥ 0'),
                      ),
                    );
                    return;
                  }
                  final ok = widget.onApply(_columns, g);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Invalid columns for this frame (gutter too large).',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Text fills column 1 first, then each next column. A red corner tab marks text that overflows the frame.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text(
            'Text flow',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._textFlowSection(),
        ],
      ),
    );
  }

  /// The live link/unlink controls for the selected frame. Derived from the
  /// controller on every build (the sheet listens), so the state reflects
  /// the project without reopening.
  List<Widget> _textFlowSection() {
    final artboards = widget.controller.project.artboards;
    if (artboards.isEmpty) {
      return const <Widget>[
        Text('No artboard.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ];
    }
    final artboard = artboards.first;
    final nodeIndex =
        artboard.nodes.indexWhere((n) => n.id == widget.selectedId);
    if (nodeIndex < 0) {
      return const <Widget>[
        Text('Selected frame not found.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ];
    }
    final node = artboard.nodes[nodeIndex];
    final successorId = textFrameSuccessor(node);
    if (successorId != null) {
      final si = artboard.nodes.indexWhere((n) => n.id.value == successorId);
      final name = si >= 0 ? artboard.nodes[si].name : successorId;
      return <Widget>[
        Text('Flows into: $name'),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('mobile_flow_unlink'),
          onPressed: _unlink,
          child: const Text('Unlink'),
        ),
      ];
    }
    final candidates = linkCandidates(artboard, node.id);
    if (candidates.isEmpty) {
      return const <Widget>[
        Text(
          'No other text frame to link to.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ];
    }
    return <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final candidate in candidates)
            OutlinedButton.icon(
              key: ValueKey('mobile_flow_link_${candidate.id.value}'),
              onPressed: () => _link(candidate.id),
              icon: const Icon(Icons.link, size: 16),
              label: Text(candidate.name),
            ),
        ],
      ),
      const SizedBox(height: 4),
      const Text(
        'Linking makes overflowing text continue into the next frame. A blue arrow marks the frame where the story continues; the red tab marks the final overflow. One undoable step per action.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    ];
  }
}

/// Owns its [TextEditingController] so the controller outlives the dialog's
/// exit animation (disposing it in the caller while the TextField was still
/// animating out crashed with "used after being disposed").
class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog();

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add text'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 256,
      decoration: const InputDecoration(labelText: 'Text'),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Add'),
      ),
    ],
  );
}

class _HistoryBar extends StatelessWidget {
  const _HistoryBar({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 2,
    borderRadius: BorderRadius.circular(24),
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Undo',
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Redo',
          onPressed: canRedo ? onRedo : null,
          icon: const Icon(Icons.redo),
        ),
      ],
    ),
  );
}

class StatusBar extends StatelessWidget {
  const StatusBar({
    required this.objectCount,
    required this.revision,
    super.key,
  });

  final int objectCount;
  final int revision;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Manual mode'),
          const Spacer(),
          Text(
            '$objectCount object${objectCount == 1 ? '' : 's'}  •  r$revision',
          ),
        ],
      ),
    ),
  );
}

/// Top-level project actions shown in the transparent overlay top bar.
/// All of them live inside the More menu by default; the user pins any of
/// them out to the bar and reorders the menu (persisted in workspace
/// preferences). Order of declaration = canonical default order.
/// Document/workspace actions of the top bar. The legacy `canvasToolbar`
/// and `dockToolbar` actions were removed with the dockable secondary
/// toolbar: the compact shell now has ONE canonical layout (stable left
/// tool rail + bottom contextual action bar) instead of a toolbar that
/// could be docked to three edges. Stored ids of removed actions fail
/// closed through the existing sanitizers.
enum EditorTopAction {
  openProject('Open project', Icons.folder_open_outlined),
  newProject('New project', Icons.note_add_outlined),
  save('Save project', Icons.save_outlined),
  diagnostics('Diagnostics export', Icons.bug_report_outlined),
  settings('Settings', Icons.tune),
  immersive('Immersive canvas', Icons.fullscreen),
  dockInspector('Dock inspector', Icons.vertical_split_outlined);

  const EditorTopAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Transparent, icon-only action bar drawn INSIDE the canvas bounds at the
/// status-bar boundary (`CanvasArea.topBar`). No background, no title: the
/// icons render in the contrast color of the surface they float over (the
/// dark canvas background, so white with a soft shadow) and every action
/// without a pinned slot lives behind the More menu.
///
/// Layout contract (device finding: "RenderFlex overflowed by 1.2 pixels
/// on the right" at 471px-class widths): the pinned region is a
/// [Flexible] horizontal scroller, so however many actions the user pins
/// — including all of them — the Row's intrinsic width can never exceed
/// its constraints. The More button keeps its fixed slot at the right
/// edge and is never pushed out.
class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.actions,
    required this.onRun,
    required this.onMore,
  });

  /// Pinned actions, in user order, drawn before the More button (left
  /// side of the bar).
  final List<EditorTopAction> actions;
  final ValueChanged<EditorTopAction> onRun;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const shadow = <Shadow>[
      Shadow(blurRadius: 6, color: Colors.black87),
      Shadow(blurRadius: 12, color: Colors.black45),
    ];
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            // Bounded pinned region: shrinks to its content when it fits
            // and scrolls when it does not, so this Row is mathematically
            // incapable of overflowing its incoming constraints.
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: IconButton(
                          tooltip: action.label,
                          onPressed: () => onRun(action),
                          icon: Icon(
                            action.icon,
                            size: 22,
                            color: Colors.white,
                            shadows: shadow,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'More actions',
              onPressed: onMore,
              icon: Icon(
                Icons.more_horiz,
                size: 26,
                color: Colors.white,
                shadows: shadow,
              ),
            ),
          ],
        ),
    );
  }
}

/// Small horizontal swatch row used in the inspector for fill/stroke color
/// selection. Tap applies immediately (one undoable style update).
class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({
    required this.selected,
    required this.colors,
    required this.onSelected,
  });

  final int selected;
  final List<int> colors;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final c in colors)
          GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white24,
                  width: c == selected ? 2.5 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

