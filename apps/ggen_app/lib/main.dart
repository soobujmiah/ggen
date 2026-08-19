import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'debug_log.dart';

final debugLog = DebugLogStore()..info('app_start', 'GGEN shell started');
final Set<String> _loggedLayoutModes = <String>{};
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
        child: SingleChildScrollView(
          child: SelectableText(payload),
        ),
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
  const GgenApp({super.key});

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
      home: const StudioShell(),
    );
  }
}

class StudioShell extends StatefulWidget {
  const StudioShell({super.key});

  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  bool _immersive = false;

  void _setImmersive(bool value) {
    setState(() => _immersive = value);
    debugLog.info('immersive_mode', value ? 'Canvas chrome hidden' : 'Canvas chrome restored');
  }

  @override
  Widget build(BuildContext context) {
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
                IconButton(
                  tooltip: 'Export diagnostics',
                  onPressed: () => _showDiagnostics(context),
                  icon: const Icon(Icons.bug_report_outlined),
                ),
                IconButton(
                  tooltip: 'Save project',
                  onPressed: () {},
                  icon: const Icon(Icons.save_outlined),
                ),
                IconButton(
                  tooltip: 'More actions',
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
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
          final inspector = showPanels && constraints.maxWidth >= 900
              ? const SizedBox(width: 280, child: InspectorPanel())
              : const SizedBox.shrink();
          return Stack(
            children: [
              Row(
                children: [
                  if (showPanels && !compact) const ToolRail(),
                  Expanded(child: CanvasArea(size: constraints.biggest)),
                  if (showPanels) inspector,
                ],
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
                  ? const CompactNavigationBar()
                  : const StatusBar(),
            ),
    );
  }
}

class ToolRail extends StatelessWidget {
  const ToolRail({super.key});

  @override
  Widget build(BuildContext context) => NavigationRail(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          debugLog.info('tool_select', 'Tool destination selected', {'index': index});
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
  const CanvasArea({required this.size, super.key});
  final Size size;

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
                return const Center(
                  child: Text('Untitled project', style: TextStyle(color: Colors.black54)),
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

class CompactNavigationBar extends StatelessWidget {
  const CompactNavigationBar({super.key});

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          debugLog.info('tool_select', 'Tool destination selected', {'index': index});
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.near_me_outlined), label: 'Select'),
          NavigationDestination(icon: Icon(Icons.brush_outlined), label: 'Draw'),
          NavigationDestination(icon: Icon(Icons.text_fields), label: 'Text'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
        ],
      );
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [Text('Manual mode'), Spacer(), Text('100%  •  0 objects')],
          ),
        ),
      );
}
