import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'debug_log.dart';

final debugLog = DebugLogStore()..info('app_start', 'GGEN shell started');

void main() => runApp(const GgenApp());


Future<void> _showDiagnostics(BuildContext context) async {
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

class StudioShell extends StatelessWidget {
  const StudioShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GGEN'),
        actions: [
          IconButton(
            tooltip: 'Save project',
            onPressed: () {},
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Export diagnostics',
            onPressed: () => _showDiagnostics(context),
            icon: const Icon(Icons.bug_report_outlined),
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
          final inspector = constraints.maxWidth >= 900
              ? const SizedBox(width: 280, child: InspectorPanel())
              : const SizedBox.shrink();
          return Row(
            children: [
              const ToolRail(),
              Expanded(child: CanvasArea(size: constraints.biggest)),
              inspector,
            ],
          );
        },
      ),
      bottomNavigationBar: const StatusBar(),
    );
  }
}

class ToolRail extends StatelessWidget {
  const ToolRail({super.key});

  @override
  Widget build(BuildContext context) => NavigationRail(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
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
            child: const Center(
              child: Text('Untitled project', style: TextStyle(color: Colors.black54)),
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
