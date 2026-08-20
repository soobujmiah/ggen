import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_core/ggen_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adds one shape node to every artboard of [project] without changing its
/// identity or revision (valid tool-session preview semantics).
DocumentProject _withNode(DocumentProject project, String name) {
  final artboards = <Artboard>[
    for (final artboard in project.artboards)
      Artboard(
        id: artboard.id,
        name: artboard.name,
        width: artboard.width,
        height: artboard.height,
        nodes: <DocumentNode>[
          ...artboard.nodes,
          DocumentNode(
            id: GgenId('node-$name'),
            kind: DocumentNodeKind.shape,
            name: name,
          ),
        ],
      ),
  ];
  return project.copyWith(artboards: artboards);
}

void main() {
  testWidgets('uses compact navigation without a side rail', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byTooltip('Dock inspector left or right'), findsNothing);
  });

  testWidgets('uses rail without inspector at tablet width', (tester) async {
    tester.view.physicalSize = const Size(800, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Inspector'), findsNothing);
    expect(find.byTooltip('Dock inspector left or right'), findsNothing);
  });

  testWidgets('uses the rail and inspector when space allows', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
    await tester.tap(find.byTooltip('Dock inspector left or right'));
    await tester.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);
  });

  testWidgets('renders the original studio shell', (tester) async {
    await tester.pumpWidget(const GgenApp());
    expect(find.text('GGEN'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Manual mode'), findsOneWidget);
  });

  testWidgets('can enter and leave immersive canvas mode', (tester) async {
    tester.view.physicalSize = const Size(471, 1020);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    await tester.tap(find.byTooltip('Immersive canvas'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Show workspace controls'), findsOneWidget);
    await tester.tap(find.byTooltip('Show workspace controls'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('undo and redo are disabled without history', (tester) async {
    await tester.pumpWidget(const GgenApp());
    final undo = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    final redo = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.redo),
    );
    expect(undo.onPressed, isNull);
    expect(redo.onPressed, isNull);
  });

  testWidgets('shell reads project name and history from the controller', (
    tester,
  ) async {
    final controller = StudioController();
    final session = controller.beginSession();
    session.updatePreview(_withNode(session.preview, 'shape-1'));
    controller.commitSession(session, 'add shape-1');

    await tester.pumpWidget(GgenApp(controller: controller));

    // Canvas shows the project name; status bar shows one object at r1.
    expect(find.text('Untitled project'), findsOneWidget);
    expect(find.textContaining('1 object'), findsOneWidget);
    expect(find.textContaining('r1'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 objects'), findsOneWidget);
    expect(find.textContaining('r0'), findsOneWidget);
    expect(find.textContaining('r1'), findsNothing);

    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 object'), findsOneWidget);
  });

  testWidgets('new project flow resets the workspace', (tester) async {
    final controller = StudioController();
    final session = controller.beginSession();
    session.updatePreview(_withNode(session.preview, 'shape-1'));
    controller.commitSession(session, 'add shape-1');

    await tester.pumpWidget(GgenApp(controller: controller));
    expect(find.textContaining('1 object'), findsOneWidget);

    await tester.tap(find.byTooltip('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Brand Studio');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Brand Studio'), findsOneWidget);
    expect(find.textContaining('0 objects'), findsOneWidget);
    expect(find.textContaining('r0'), findsOneWidget);
  });

  testWidgets('shell starts fresh with a stale stored project key', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'workspace.last_project_key': 'project-nonexistent',
    });
    await tester.pumpWidget(const GgenApp());
    await tester.pumpAndSettle();
    expect(find.text('Untitled project'), findsOneWidget);
    expect(find.textContaining('r0'), findsOneWidget);
  });

  testWidgets('shell starts fresh with a malformed stored project key', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'workspace.last_project_key': 'NOT A VALID KEY!',
    });
    await tester.pumpWidget(const GgenApp());
    await tester.pumpAndSettle();
    expect(find.text('Untitled project'), findsOneWidget);
    expect(find.textContaining('r0'), findsOneWidget);
  });

  group('adaptive layouts', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const GgenApp());
      await tester.pumpAndSettle();
    }

    testWidgets('compact phone (<700): bottom navigation, no rail', (
      tester,
    ) async {
      await pumpAt(tester, const Size(400, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('small tablet (700-899): rail without inspector', (
      tester,
    ) async {
      await pumpAt(tester, const Size(800, 1024));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Inspector'), findsNothing);
    });

    testWidgets('wide (>=900): rail with inspector on the right', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1200, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Inspector'), findsOneWidget);
      expect(find.byTooltip('Dock inspector left or right'), findsOneWidget);
    });

    testWidgets('wide inspector can dock left', (tester) async {
      await pumpAt(tester, const Size(1200, 800));
      expect(find.text('Inspector'), findsOneWidget);
      await tester.tap(find.byTooltip('Dock inspector left or right'));
      await tester.pumpAndSettle();
      expect(find.text('Inspector'), findsOneWidget);
    });

    testWidgets('tiny and zero-size viewports do not crash', (tester) async {
      await pumpAt(tester, const Size(200, 300));
      expect(tester.takeException(), isNull);
      await pumpAt(tester, const Size(0, 0));
      expect(tester.takeException(), isNull);
    });
  });
}
