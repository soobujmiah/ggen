import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'debug_log.dart';
import 'workspace_preferences.dart';
import 'workspace_profile.dart';
import 'profile_manager_sheet.dart';
import 'src/controller/studio_controller.dart';
import 'src/canvas/studio_canvas.dart';
import 'src/canvas/canvas_zoom_controller.dart';
import 'src/layers/layer_list.dart';
import 'src/storage/file_project_store.dart';
import 'src/storage/file_recovery_journal.dart';

import 'package:ggen_core/ggen_core.dart';

final debugLog = DebugLogStore()..info('app_start', 'GGEN shell started');
final Set<String> _loggedLayoutModes = <String>{};

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
  bool _secondaryToolbarCollapsed = false;
  List<EditorTopAction> _topActionOrder = List<EditorTopAction>.of(
    EditorTopAction.values,
  );
  Set<EditorTopAction> _topActionPinned = <EditorTopAction>{};
  final CanvasZoomController _zoomController = CanvasZoomController();
  bool _canvasFirst = true;
  bool _workspaceSettingsOpen = false;
  InspectorDock _inspectorDock = InspectorDock.right;
  int _selectedTool = 0;

  static const List<String> _toolNames = <String>['Select', 'Draw', 'Text'];

  void _selectTool(int index) {
    setState(() => _selectedTool = index);
    debugLog.info('tool_select', 'Tool destination selected', {
      'index': index,
      'tool': _toolNames[index],
    });
  }

  void _toggleGrid() {
    setState(() => _showGrid = !_showGrid);
    debugLog.info(
      'grid_toggle',
      _showGrid ? 'Grid overlay enabled' : 'Grid overlay disabled',
    );
  }

  @override
  void initState() {
    super.initState();
    _ownsStudio = widget.controller == null;
    _studio = widget.controller ?? StudioController();
    _studio.addListener(_onStudioChanged);
    _restoreWorkspace();
    unawaited(_initStorage());
    HardwareKeyboard.instance.addHandler(_handleVolumeKey);
  }

  void _onStudioChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant StudioShell oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _studio.removeListener(_onStudioChanged);
    // Method tear-offs of the same method on the same instance compare
    // equal, so this removes the handler added in initState.
    HardwareKeyboard.instance.removeHandler(_handleVolumeKey);
    if (_ownsStudio) _studio.dispose();
    _zoomController.dispose();
    super.dispose();
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
      _secondaryToolbarCollapsed = prefs.secondaryToolbarCollapsed;
      _topActionOrder = _sanitizeActionOrder(prefs.topActionOrder);
      _topActionPinned = _sanitizePinned(prefs.topActionPinned);
    });
    debugLog.info('workspace_restore', 'Workspace preferences restored', {
      'inspector_visible': _showInspector,
      'canvas_first': _canvasFirst,
      'inspector_dock': _inspectorDock.name,
      'secondary_toolbar_collapsed': _secondaryToolbarCollapsed,
      'top_action_pinned': _topActionPinned.length,
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

  Future<void> _persistWorkspace() => WorkspacePreferences(
    inspectorVisible: _showInspector,
    canvasFirst: _canvasFirst,
    inspectorDock: _inspectorDock.name,
    secondaryToolbarCollapsed: _secondaryToolbarCollapsed,
    topActionOrder: <String>[for (final a in _topActionOrder) a.name],
    topActionPinned: <String>[
      for (final a in _topActionOrder)
        if (_topActionPinned.contains(a)) a.name,
    ],
  ).save();

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

  /// Shows the More menu: every top action in configurable order with pin
  /// (show in the top bar) and reorder (up/down) controls; tapping a row
  /// runs the action.
  Future<void> _showMoreMenu() async {
    debugLog.info('top_action_more', 'More menu opened');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'More actions',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              for (var i = 0; i < _topActionOrder.length; i++)
                _buildMoreRow(sheetContext, i, setSheetState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreRow(
    BuildContext sheetContext,
    int index,
    StateSetter setSheetState,
  ) {
    final action = _topActionOrder[index];
    final pinned = _topActionPinned.contains(action);
    return ListTile(
      dense: true,
      leading: IconButton(
        tooltip: pinned ? 'Hide from top bar' : 'Show in top bar',
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
        onPressed: () {
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
      onTap: () {
        debugLog.info('top_action_run', 'Action run from More menu', {
          'action': action.name,
        });
        Navigator.pop(sheetContext);
        unawaited(_runTopAction(action));
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Move up',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
            onPressed: index == 0
                ? null
                : () {
                    setSheetState(() {
                      final prev = _topActionOrder[index - 1];
                      _topActionOrder[index - 1] = action;
                      _topActionOrder[index] = prev;
                    });
                    setState(() {});
                    debugLog.info(
                      'top_action_reorder',
                      'Action moved up',
                      {'action': action.name},
                    );
                    unawaited(_persistWorkspace());
                  },
            icon: const Icon(Icons.arrow_upward),
          ),
          IconButton(
            tooltip: 'Move down',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
            onPressed: index == _topActionOrder.length - 1
                ? null
                : () {
                    setSheetState(() {
                      final next = _topActionOrder[index + 1];
                      _topActionOrder[index + 1] = action;
                      _topActionOrder[index] = next;
                    });
                    setState(() {});
                    debugLog.info(
                      'top_action_reorder',
                      'Action moved down',
                      {'action': action.name},
                    );
                    unawaited(_persistWorkspace());
                  },
            icon: const Icon(Icons.arrow_downward),
          ),
        ],
      ),
    );
  }

  void _toggleSecondaryToolbar() {
    setState(() => _secondaryToolbarCollapsed = !_secondaryToolbarCollapsed);
    debugLog.info(
      'canvas_toolbar_toggle',
      _secondaryToolbarCollapsed
          ? 'Canvas toolbar collapsed'
          : 'Canvas toolbar expanded',
    );
    unawaited(_persistWorkspace());
  }

  void _setImmersive(bool value) {
    setState(() => _immersive = value);
    // Hide the system bars in fullscreen so the canvas reaches the true
    // screen edges instead of drawing under the status bar (device report:
    // "fullscreen overlaps the status bar"). Restoring returns to normal
    // edge-to-edge with bars visible; the SafeArea below guards the canvas
    // from insets whenever the bars remain visible.
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
    debugLog.info(
      'immersive_mode',
      value ? 'Canvas chrome hidden' : 'Canvas chrome restored',
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
      await WorkspacePreferences(
        inspectorVisible: _showInspector,
        canvasFirst: _canvasFirst,
        inspectorDock: _inspectorDock.name,
        lastProjectKey: receipt.key.value,
        secondaryToolbarCollapsed: _secondaryToolbarCollapsed,
        topActionOrder: <String>[for (final a in _topActionOrder) a.name],
        topActionPinned: <String>[
          for (final a in _topActionOrder)
            if (_topActionPinned.contains(a)) a.name,
        ],
      ).save();
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _studio,
      builder: (context, _) {
        return Scaffold(
          appBar: null,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              _recordLayout(
                _immersive
                    ? 'immersive_canvas'
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
                // In immersive mode the app bar is gone so the body starts
                // at the screen top; keep the canvas below the status bar
                // (and above the gesture bar) whenever system bars remain
                // visible.
                top: _immersive,
                bottom: _immersive,
                left: false,
                right: false,
                child: Stack(
                children: [
                  Row(
                    children: [
                      if (showPanels && !compact)
                        ToolRail(
                          selectedIndex: _selectedTool,
                          onSelected: _selectTool,
                        ),
                      if (showPanels &&
                          !compact &&
                          _showInspector &&
                          _inspectorDock == InspectorDock.left)
                        inspector,
                      Expanded(
                        child: CanvasArea(
                          size: constraints.biggest,
                          projectName: _studio.project.name,
                          controller: _studio,
                          drawEnabled: _selectedTool == 1,
                          selectMode: _selectedTool == 0,
                          textEnabled: _selectedTool == 2,
                          immersive: _immersive,
                          multiSelectMode: _multiSelect,
                          gridVisible: _showGrid,
                          onToggleGrid: _toggleGrid,
                          selectedNodeId: _studio.selectedNodeId,
                          topBar: _TopActionBar(
                            actions: _pinnedInOrder,
                            onRun: (action) => unawaited(_runTopAction(action)),
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
                          !compact &&
                          _showInspector &&
                          _inspectorDock == InspectorDock.right)
                        inspector,
                      if (showPanels && !compact && _showLayers)
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
                  if (!_immersive && !compact)
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
                  if (!_immersive && !compact)
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
                            if (compact) {
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
                            _showLayers && !compact
                                ? Icons.layers_clear_outlined
                                : Icons.layers_outlined,
                          ),
                        ),
                      ),
                    ),
                ],
                ),
              );
            },
          ),
          bottomNavigationBar: _immersive
              ? null
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 700;
                    if (isCompact) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Secondary toolbar — multi-select, undo/redo, layers, zoom same 40×40, equal distance, above holding bar
                          _SecondaryCanvasToolbar(
                            controller: _studio,
                            zoomController: _zoomController,
                            showLayers: _showLayers,
                            multiSelect: _multiSelect,
                            gridVisible: _showGrid,
                            collapsed: _secondaryToolbarCollapsed,
                            onToggleCollapsed: _toggleSecondaryToolbar,
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
                            onToggleLayers: () {
                              // Toolbar only shown when isCompact, so always sheet
                              _showLayersSheet();
                              debugLog.info('layers_toggle', 'Layers via toolbar');
                            },
                          ),
                          const Divider(height: 1),
                          // Settings moved into the top-bar More menu (device
                          // feedback); the bottom bar is tools-only now.
                          CompactNavigationBar(
                            selectedIndex: _selectedTool,
                            onSelected: _selectTool,
                          ),
                        ],
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

class ToolRail extends StatelessWidget {
  const ToolRail({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationRail(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    labelType: NavigationRailLabelType.all,
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.near_me_outlined),
        selectedIcon: Icon(Icons.near_me),
        label: Text('Select'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.brush_outlined),
        selectedIcon: Icon(Icons.brush),
        label: Text('Draw'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.text_fields),
        label: Text('Text'),
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
    this.onTextRequest,
    this.onNodeSelected,
    this.onTwoFingerTap,
    this.onThreeFingerTap,
    super.key,
  });

  final Size size;
  final String projectName;
  final StudioController controller;
  final bool drawEnabled;
  final VoidCallback onNodeAdded;
  final bool selectMode;
  final bool textEnabled;

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
            // toolbar, so the in-canvas zoom overlay is redundant there;
            // wide layouts and immersive keep it (single source of zoom UI).
            final compact = size.width < 700;
            return RepaintBoundary(
              child: StudioCanvas(
                controller: controller,
                drawEnabled: drawEnabled,
                onNodeAdded: onNodeAdded,
                selectMode: selectMode,
                textEnabled: textEnabled,
                showZoomOverlay: immersive || !compact,
                multiSelectMode: multiSelectMode,
                gridVisible: gridVisible,
                onToggleGrid: onToggleGrid,
                selectedNodeId: selectedNodeId,
                zoomController: zoomController,
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
        Positioned(
          top: topBar == null ? 12 : 56,
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
              _InspectorContent(controller: controller, selectedId: selectedId),
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

  DocumentNode? _node;
  NodeGeometry? _geom;
  TextNodeGeometry? _textGeom;

  @override
  void initState() {
    super.initState();
    _xCtrl = TextEditingController();
    _yCtrl = TextEditingController();
    _wCtrl = TextEditingController();
    _hCtrl = TextEditingController();
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
    super.dispose();
  }

  void _syncFromNode() {
    final artboards = widget.controller.project.artboards;
    final nodes = artboards.isEmpty ? const <DocumentNode>[] : artboards.first.nodes;
    final idx = nodes.indexWhere((n) => n.id == widget.selectedId);
    if (idx < 0) return;
    final node = nodes[idx];
    final geom = nodeGeometry(node);
    final tgeom = textNodeGeometry(node);
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
      } else if (tgeom != null) {
        _xCtrl.text = tgeom.x.toStringAsFixed(1);
        _yCtrl.text = tgeom.y.toStringAsFixed(1);
        _wCtrl.text = '';
        _hCtrl.text = '';
      }
    });
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
              label: const Text('Apply'),
            ),
          ),
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
          Text('Text • "${tgeom.text}"', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _NumberField(label: 'X', controller: _xCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _NumberField(label: 'Y', controller: _yCtrl)),
          ]),
          const SizedBox(height: 8),
          Text('Text content and size editing decoupled from geometry; use Text tool to recreate or future text inspector.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 11)),
        ],
      );
    }
    return Text('Unknown node kind: ${node.kind.name}');
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
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

class _SecondaryCanvasToolbar extends StatelessWidget {
  const _SecondaryCanvasToolbar({
    required this.controller,
    required this.zoomController,
    required this.showLayers,
    required this.multiSelect,
    required this.gridVisible,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onToggleGrid,
    required this.onToggleMultiSelect,
    required this.onToggleLayers,
    super.key,
  });

  final StudioController controller;
  final CanvasZoomController zoomController;
  final bool showLayers;
  final bool multiSelect;
  final bool gridVisible;

  /// When true only the expand handle is shown (the toolbar is collapsible
  /// and expandable — device feedback).
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleMultiSelect;
  final VoidCallback onToggleLayers;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, zoomController]),
      builder: (context, _) {
        final canUndo = controller.canUndo;
        final canRedo = controller.canRedo;
        final buttons = <Widget>[
          // Multi-select toggle — Select-tool taps extend the selection
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: multiSelect ? 'Multi-select on' : 'Multi-select off',
              onPressed: onToggleMultiSelect,
              isSelected: multiSelect,
              icon: Icon(
                multiSelect ? Icons.done_all : Icons.done_all_outlined,
                size: 20,
              ),
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: multiSelect
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
              ),
            ),
          ),
          // Grid overlay — pairs with Ctrl-snap; same 40×40 style
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: gridVisible ? 'Hide grid' : 'Show grid',
              onPressed: onToggleGrid,
              isSelected: gridVisible,
              icon: const Icon(Icons.grid_4x4, size: 20),
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: gridVisible
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
              ),
            ),
          ),
          Container(width: 1, height: 24, color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          // Undo / Redo — same 40×40 size, equal spacing
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Undo',
              onPressed: canUndo ? () { controller.undo(); debugLog.info('history_undo', 'Undo via toolbar'); } : null,
              icon: const Icon(Icons.undo, size: 20),
              style: IconButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Redo',
              onPressed: canRedo ? () { controller.redo(); debugLog.info('history_redo', 'Redo via toolbar'); } : null,
              icon: const Icon(Icons.redo, size: 20),
              style: IconButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
          Container(width: 1, height: 24, color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          // Layers — same size
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: showLayers ? 'Hide layers' : 'Show layers',
              onPressed: onToggleLayers,
              icon: Icon(showLayers ? Icons.layers_clear_outlined : Icons.layers_outlined, size: 20),
              style: IconButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
          Container(width: 1, height: 24, color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          // Zoom — same 40 size, equal spacing, above holding bar per device feedback
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Zoom out',
              onPressed: () { zoomController.zoomOut(); debugLog.info('toolbar_zoom_out', 'Zoom out via toolbar'); },
              icon: const Icon(Icons.remove, size: 20),
              style: IconButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Zoom in',
              onPressed: () { zoomController.zoomIn(); debugLog.info('toolbar_zoom_in', 'Zoom in via toolbar'); },
              icon: const Icon(Icons.add, size: 20),
              style: IconButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Fit to screen',
              onPressed: () { zoomController.fitToScreen(); debugLog.info('toolbar_zoom_fit', 'Fit via toolbar'); },
              icon: const Icon(Icons.fit_screen_outlined, size: 20),
              style: IconButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
        ];
        if (collapsed) {
          return Container(
            height: 40,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Show canvas toolbar',
                  onPressed: onToggleCollapsed,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  iconSize: 20,
                ),
              ],
            ),
          );
        }
        final expandedButtons = <Widget>[
          ...buttons,
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Hide canvas toolbar',
            onPressed: onToggleCollapsed,
            icon: const Icon(Icons.keyboard_arrow_down),
            iconSize: 20,
          ),
        ];
        return Container(
          height: 48,
          color: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          // At degenerate/very narrow widths (e.g. the 200px test viewport)
          // the fixed 40×40 buttons would overflow; keep the toolbar
          // scrollable there while preserving the even-spaced layout at
          // real widths.
          child: LayoutBuilder(
            builder: (context, constraints) {
              const contentWidth = 40 * 9 + 3 + 16.0; // 9 buttons + 3 dividers + padding
              if (constraints.maxWidth >= contentWidth) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: expandedButtons,
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: expandedButtons),
              );
            },
          ),
        );
      },
    );
  }
}

class CompactNavigationBar extends StatelessWidget {
  const CompactNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 56,
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.near_me_outlined),
        label: 'Select',
      ),
      NavigationDestination(icon: Icon(Icons.brush_outlined), label: 'Draw'),
      NavigationDestination(icon: Icon(Icons.text_fields), label: 'Text'),
    ],
  );
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
enum EditorTopAction {
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
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
      ),
    );
  }
}

