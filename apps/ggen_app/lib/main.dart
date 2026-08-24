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
import 'src/text_flow/linked_text_flow.dart';
import 'src/workspace/studio_tool.dart';
import 'src/workspace/control_layout.dart';
import 'src/workspace/workspace_bars.dart';
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
  List<EditorTopAction> _topActionOrder = List<EditorTopAction>.of(
    EditorTopAction.values,
  );
  Set<EditorTopAction> _topActionPinned = <EditorTopAction>{};
  final CanvasZoomController _zoomController = CanvasZoomController();
  bool _canvasFirst = true;
  bool _workspaceSettingsOpen = false;
  InspectorDock _inspectorDock = InspectorDock.right;

  /// User-defined fullscreen (immersive) control placement. Normalized by
  /// [CanvasControlLayout.resolve] so rendering is always deterministic and
  /// the immersive exit control is always present.
  CanvasControlLayout _fullscreenLayout = CanvasControlLayout.defaults()
      .resolve();

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
      _topActionOrder = _sanitizeActionOrder(prefs.topActionOrder);
      _topActionPinned = _sanitizePinned(prefs.topActionPinned);
      _fullscreenLayout = CanvasControlLayout.fromPrefs(
        prefs.fullscreenRegions,
      );
    });
    debugLog.info('workspace_restore', 'Workspace preferences restored', {
      'inspector_visible': _showInspector,
      'canvas_first': _canvasFirst,
      'inspector_dock': _inspectorDock.name,
      'top_action_pinned': _topActionPinned.length,
      'fullscreen_regions': _fullscreenLayout.regions.length,
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
    topActionOrder: <String>[for (final a in _topActionOrder) a.name],
    topActionPinned: <String>[
      for (final a in _topActionOrder)
        if (_topActionPinned.contains(a)) a.name,
    ],
    fullscreenRegions: _fullscreenLayout.toPrefs(),
  ).save();

  /// Opens the fullscreen control customization sheet: every
  /// [CanvasControl] with a region picker (6 regions + Hidden), a reset
  /// button, and immediate persistence. In fullscreen the same placement is
  /// also reachable by long-pressing a control cluster and dragging it to
  /// another corner (see [_onClusterDragEnd]).
  Future<void> _openFullscreenCustomizer() async {
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
          ControlRegion? regionOf(CanvasControl control) {
            for (final entry in _fullscreenLayout.regions.entries) {
              if (entry.value.contains(control)) return entry.key;
            }
            return null;
          }

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
                              setState(
                                () =>
                                    _fullscreenLayout = CanvasControlLayout
                                        .defaults()
                                        .resolve(),
                              );
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
                      'Choose where each control appears in fullscreen. In '
                      'fullscreen, long-press a control cluster and drag it '
                      'to another corner to move it.',
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
                            trailing: PopupMenuButton<ControlRegion?>(
                              initialValue: regionOf(control),
                              onSelected: (target) {
                                setSheetState(
                                  () => _moveFullscreenControl(
                                    control,
                                    target,
                                    sheetContext,
                                  ),
                                );
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem<ControlRegion?>(
                                  value: null,
                                  child: Text('Hidden'),
                                ),
                                for (final region in ControlRegion.values)
                                  PopupMenuItem<ControlRegion?>(
                                    value: region,
                                    child: Text(region.label),
                                  ),
                              ],
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    regionOf(control)?.label ?? 'Hidden',
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
  /// from any region, optionally appends it to the chosen region, enforces
  /// the per-region capacity, and persists. The immersive exit control can
  /// never be hidden (the user must always be able to leave fullscreen).
  void _moveFullscreenControl(
    CanvasControl control,
    ControlRegion? target,
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
    final map = <ControlRegion, List<CanvasControl>>{
      for (final entry in _fullscreenLayout.regions.entries)
        entry.key: [...entry.value],
    };
    for (final list in map.values) {
      list.remove(control);
    }
    if (target != null) {
      final targetList = map[target] ?? <CanvasControl>[];
      if (targetList.length >= CanvasControlLayout.maxControlsPerRegion) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(
            content: Text(
              '${target.label} is full '
              '(${CanvasControlLayout.maxControlsPerRegion} max)',
            ),
          ),
        );
        return;
      }
      map[target] = [...targetList, control];
    }
    setState(() => _fullscreenLayout = CanvasControlLayout(map).resolve());
    unawaited(_persistWorkspace());
    debugLog.info(
      'fullscreen_control_place',
      'Fullscreen control placement updated',
      {'control': control.name, 'region': target?.name ?? 'hidden'},
    );
  }

  /// Resolves the controls of one fullscreen region into concrete shell
  /// actions (same enablement rules as the compact bar): undo/redo need
  /// history, multi-select needs the Select tool, Columns needs a selected
  /// text frame.
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
    return [
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
  }

  /// Builds one fullscreen control cluster for [region], draggable to
  /// another region via [_onClusterDragEnd]. Width-bounded and horizontally
  /// scrollable so it can never overflow or be clipped at any screen size.
  Widget _fullscreenCluster(
    ControlRegion region,
    List<CanvasControl> controls,
    BoxConstraints constraints,
  ) {
    final maxWidth = constraints.maxWidth - 16;
    final cluster = CanvasControlCluster(
      actions: _resolveFullscreenActions(controls),
      maxWidth: maxWidth,
    );
    return _regionPositioned(
      region,
      LongPressDraggable<ControlRegion>(
        data: region,
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(22),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Opacity(opacity: 0.92, child: cluster),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: cluster),
        onDragEnd: (details) =>
            _onClusterDragEnd(region, details.offset, constraints.biggest),
        child: cluster,
      ),
    );
  }

  /// Positions a fullscreen control cluster in [region], respecting the
  /// camera cutout via [MediaQuery.viewPadding] so controls stay tappable
  /// even while the canvas itself draws under the notch.
  Widget _regionPositioned(
    ControlRegion region,
    Widget child,
  ) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final padded = Padding(
      padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
      child: child,
    );
    switch (region) {
      case ControlRegion.topLeft:
        return Positioned(top: 8, left: 8, child: padded);
      case ControlRegion.topRight:
        return Positioned(top: 8, right: 8, child: padded);
      case ControlRegion.topCenter:
        return Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(child: padded),
        );
      case ControlRegion.bottomLeft:
        return Positioned(bottom: 8, left: 8, child: padded);
      case ControlRegion.bottomRight:
        return Positioned(bottom: 8, right: 8, child: padded);
      case ControlRegion.bottomCenter:
        return Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(child: padded),
        );
    }
  }

  /// Drag-snap for a fullscreen control cluster: computes the nearest region
  /// from the drop point (deterministic thirds/halves math) and moves the
  /// whole cluster there, persisting the new placement.
  void _onClusterDragEnd(
    ControlRegion origin,
    Offset drop,
    Size viewport,
  ) {
    final target = CanvasControlLayout.nearestRegion(drop, viewport);
    if (target == origin) return;
    final controls = _fullscreenLayout.regions[origin];
    if (controls == null || controls.isEmpty) return;
    final map = <ControlRegion, List<CanvasControl>>{
      for (final entry in _fullscreenLayout.regions.entries)
        entry.key: [...entry.value],
    };
    map.remove(origin);
    final incoming = [...controls];
    map[target] = [
      ...?map[target],
      ...incoming,
    ].take(CanvasControlLayout.maxControlsPerRegion).toList(growable: false);
    setState(() => _fullscreenLayout = CanvasControlLayout(map).resolve());
    unawaited(_persistWorkspace());
    debugLog.info(
      'fullscreen_control_move',
      'Fullscreen control cluster moved',
      {
        'from': origin.name,
        'to': target.name,
        'controls': controls.length,
      },
    );
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
      await WorkspacePreferences(
        inspectorVisible: _showInspector,
        canvasFirst: _canvasFirst,
        inspectorDock: _inspectorDock.name,
        lastProjectKey: receipt.key.value,
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
                // The canvas must NEVER draw under the status bar in normal
                // mode (device feedback: the canvas and zoomed content slid
                // under the status bar). Top inset is therefore always
                // consumed here; in immersive the system bars are hidden so
                // the inset is 0 and the canvas still reaches the true
                // screen top.
                top: true,
                bottom: _immersive,
                left: false,
                right: false,
                child: Stack(
                children: [
                  Row(
                    children: [
                      // Canonical mobile workspace: a stable vertical tool
                      // rail on the left (phone portrait) — primary tools
                      // never move between edges.
                      if (showPanels &&
                          cls == WorkspaceClass.compactPortrait)
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
                  // Fullscreen control regions: the user's chosen controls
                  // rendered as persistent clusters, replacing the default
                  // top bar and the legacy fixed zoom overlay.
                  if (_immersive)
                    for (final region in ControlRegion.values)
                      if (_fullscreenLayout.regions[region]
                          case final controls?
                          when controls.isNotEmpty)
                        _fullscreenCluster(region, controls, constraints),
                ],
                ),
              );
            },
          ),
          bottomNavigationBar: _immersive
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
                    if (cls == WorkspaceClass.compactLandscape) {
                      // Landscape phones: ONE compact bar (tools | history |
                      // zoom | view | context), no left rail and no status
                      // bar, so the canvas keeps the maximum usable area.
                      return LandscapeBar(
                        controller: _studio,
                        zoomController: _zoomController,
                        activeTool: _tool,
                        onSelectedTool: _selectTool,
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
                            'Layers via landscape bar',
                          );
                        },
                        multiSelect: _multiSelect,
                        columnsEnabled: _columnsEnabled,
                        onConfigureColumns: _showColumnsSheet,
                        onDiagnostic: (event) =>
                            debugLog.info(event, 'Landscape bar control used'),
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

