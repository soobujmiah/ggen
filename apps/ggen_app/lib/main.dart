import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'debug_log.dart';
import 'workspace_preferences.dart';
import 'workspace_profile.dart';
import 'profile_manager_sheet.dart';
import 'src/controller/studio_controller.dart';
import 'src/storage/file_project_store.dart';
import 'src/storage/file_recovery_journal.dart';

import 'package:ggen_core/ggen_core.dart';

final debugLog = DebugLogStore()..info('app_start', 'GGEN shell started');
final Set<String> _loggedLayoutModes = <String>{};

enum InspectorDock { left, right }

final Set<String> _loggedCanvasGeometries = <String>{};

void _recordCanvasGeometry(BuildContext context, Size size) {
  if (size.width <= 0 || size.height <= 0) return;
  final padding = MediaQuery.paddingOf(context);
  final insets = MediaQuery.viewInsetsOf(context);
  final key = '${size.width.round()}x${size.height.round()}';
  if (_loggedCanvasGeometries.add(key)) {
    debugLog.info('canvas_geometry', 'Canvas bounds measured', {
      'width': size.width.round(),
      'height': size.height.round(),
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
  bool _canvasFirst = true;
  bool _workspaceSettingsOpen = false;
  InspectorDock _inspectorDock = InspectorDock.right;

  @override
  void initState() {
    super.initState();
    _ownsStudio = widget.controller == null;
    _studio = widget.controller ?? StudioController();
    _restoreWorkspace();
    unawaited(_initStorage());
  }

  @override
  void dispose() {
    if (_ownsStudio) _studio.dispose();
    super.dispose();
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
    if (key == null) return;
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
    });
    debugLog.info('workspace_restore', 'Workspace preferences restored', {
      'inspector_visible': _showInspector,
      'canvas_first': _canvasFirst,
      'inspector_dock': _inspectorDock.name,
    });
  }

  Future<void> _persistWorkspace() => WorkspacePreferences(
    inspectorVisible: _showInspector,
    canvasFirst: _canvasFirst,
    inspectorDock: _inspectorDock.name,
  ).save();

  void _setImmersive(bool value) {
    setState(() => _immersive = value);
    debugLog.info(
      'immersive_mode',
      value ? 'Canvas chrome hidden' : 'Canvas chrome restored',
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
    _studio.newProject(trimmed);
    debugLog.info('project_new', 'New project created', {'name': trimmed});
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
      ).save();
      if (!mounted) return;
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
      if (!mounted) return;
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
          appBar: _immersive
              ? null
              : AppBar(
                  title: const Text('GGEN'),
                  actions: [
                    IconButton(
                      tooltip: 'Immersive canvas',
                      onPressed: () => _setImmersive(true),
                      icon: const Icon(Icons.fullscreen),
                    ),
                    Builder(
                      builder: (context) {
                        if (MediaQuery.sizeOf(context).width < 900)
                          return const SizedBox.shrink();
                        return IconButton(
                          tooltip: 'Dock inspector left or right',
                          onPressed: () {
                            setState(() {
                              if (_showInspector) {
                                _inspectorDock =
                                    _inspectorDock == InspectorDock.left
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
                          },
                          icon: Icon(
                            _inspectorDock == InspectorDock.left
                                ? Icons.keyboard_double_arrow_left
                                : Icons.keyboard_double_arrow_right,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Export diagnostics',
                      onPressed: () => _showDiagnostics(context),
                      icon: const Icon(Icons.bug_report_outlined),
                    ),
                    IconButton(
                      tooltip: 'New project',
                      onPressed: () => _newProject(context),
                      icon: const Icon(Icons.note_add_outlined),
                    ),
                    IconButton(
                      tooltip: 'Save project',
                      onPressed: () => _saveProject(context),
                      icon: const Icon(Icons.save_outlined),
                    ),
                  ],
                ),
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
                  ? const SizedBox(width: 280, child: InspectorPanel())
                  : const SizedBox.shrink();
              return Stack(
                children: [
                  Row(
                    children: [
                      if (showPanels && !compact) const ToolRail(),
                      if (showPanels &&
                          !compact &&
                          _showInspector &&
                          _inspectorDock == InspectorDock.left)
                        inspector,
                      Expanded(
                        child: CanvasArea(
                          size: constraints.biggest,
                          projectName: _studio.project.name,
                        ),
                      ),
                      if (showPanels &&
                          !compact &&
                          _showInspector &&
                          _inspectorDock == InspectorDock.right)
                        inspector,
                    ],
                  ),
                  if (!_immersive)
                    Positioned(
                      top: 12,
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
                  if (_immersive)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: SafeArea(
                        child: IconButton.filledTonal(
                          tooltip: 'Show workspace controls',
                          onPressed: () => _setImmersive(false),
                          icon: const Icon(Icons.fullscreen_exit),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          bottomNavigationBar: _immersive
              ? null
              : LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 700
                      ? CompactNavigationBar(
                          onSelected: (index) {
                            if (index == 3 && !_workspaceSettingsOpen) {
                              _workspaceSettingsOpen = true;
                              unawaited(
                                _showWorkspaceSettings(
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
                                      _inspectorDock =
                                          profile.inspectorDock == 'left'
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
                                      value
                                          ? 'Canvas-first enabled'
                                          : 'Canvas-first disabled',
                                    );
                                  },
                                  onReset: () {
                                    setState(() {
                                      _showInspector = true;
                                      _canvasFirst = true;
                                      _inspectorDock = InspectorDock.right;
                                    });
                                    unawaited(WorkspacePreferences().clear());
                                  },
                                ).whenComplete(
                                  () => _workspaceSettingsOpen = false,
                                ),
                              );
                            }
                          },
                        )
                      : StatusBar(
                          objectCount: _studio.objectCount,
                          revision: _studio.revision,
                        ),
                ),
        );
      },
    );
  }
}

class ToolRail extends StatelessWidget {
  const ToolRail({super.key});

  @override
  Widget build(BuildContext context) => NavigationRail(
    selectedIndex: 0,
    onDestinationSelected: (index) {
      debugLog.info('tool_select', 'Tool destination selected', {
        'index': index,
      });
    },
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
  const CanvasArea({required this.size, required this.projectName, super.key});
  final Size size;
  final String projectName;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xff101217),
    alignment: Alignment.center,
    child: AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(blurRadius: 24, color: Colors.black54)],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _recordCanvasGeometry(context, constraints.biggest);
            return Center(
              child: Text(
                projectName,
                style: const TextStyle(color: Colors.black54),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    margin: EdgeInsets.all(12),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Text('Select an object to inspect its properties.'),
        ],
      ),
    ),
  );
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

class CompactNavigationBar extends StatelessWidget {
  const CompactNavigationBar({this.onSelected, super.key});
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: 0,
    onDestinationSelected: (index) {
      debugLog.info('tool_select', 'Tool destination selected', {
        'index': index,
      });
      onSelected?.call(index);
    },
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.near_me_outlined),
        label: 'Select',
      ),
      NavigationDestination(icon: Icon(Icons.brush_outlined), label: 'Draw'),
      NavigationDestination(icon: Icon(Icons.text_fields), label: 'Text'),
      NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
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
