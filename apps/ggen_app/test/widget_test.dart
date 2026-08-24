import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
import 'package:ggen_app/src/canvas/studio_canvas.dart';
import 'package:ggen_app/src/layers/layer_list.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_core/ggen_core.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test double for the platform documents directory. The storage-init path
/// (getApplicationDocumentsDirectory) reaches the plugin on real devices but
/// throws MissingPluginException in the test environment; without this fake
/// the file-backed swap code path is never exercised in CI — which is how
/// the LateInitializationError from the late-final reassignment escaped.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Forces the unavailable-plugin fallback path deterministically. (Without
/// it the test environment varies: flutter test loads the Dart plugin
/// registrant, so path_provider_linux can make the documents directory
/// succeed instead of throwing MissingPluginException.)
class _ThrowingPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      throw MissingPluginException('path_provider unavailable in test');
}

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
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dock inspector'));
    await tester.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);
  });

  testWidgets('renders the overlay studio shell (no app bar)', (tester) async {
    await tester.pumpWidget(const GgenApp());
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('GGEN'), findsNothing);
    expect(find.byTooltip('More actions'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Manual mode'), findsOneWidget);
  });

  testWidgets('can enter and leave immersive canvas mode', (tester) async {
    tester.view.physicalSize = const Size(471, 1020);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Immersive canvas'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    // Leave again through the same More entry (it toggles).
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Immersive canvas'));
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

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New project'));
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

  testWidgets('canvas-first switch toggles and reflects taps', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    await tester.pumpAndSettle();

    // Open the workspace settings sheet via the top-bar More menu
    // (Settings moved out of the bottom navigation).
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(SwitchListTile);
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

    // Tap on -> off; the switch must reflect the new value immediately.
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    // Tap off -> on again; it must come back (regression: a captured-value
    // switch would stay frozen and every tap would report the same state).
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
  });

  testWidgets('draw tool works through the shell (nav then canvas tap)',
      (tester) async {
    // Reproduces the device flow: select Draw in the bottom bar, then tap
    // the canvas. This failed to produce node_add events on-device, so it
    // is pinned here as an integration test.
    final controller = StudioController();
    await tester.pumpWidget(GgenApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.objectCount, 0);
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(StudioCanvas));
    await tester.pumpAndSettle();

    expect(controller.objectCount, 1, reason: 'canvas tap must add a shape');
    expect(controller.revision, 1);
    expect(controller.canUndo, isTrue);
  });

  testWidgets('text tool adds a text frame through the shell dialog',
      (tester) async {
    final controller = StudioController();
    await tester.pumpWidget(GgenApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(StudioCanvas));
    await tester.pumpAndSettle();

    // The text dialog appears; enter text and confirm.
    expect(find.text('Add text'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Hello GGEN');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(controller.objectCount, 1);
    expect(
      controller.project.artboards.first.nodes.single.kind,
      DocumentNodeKind.textFrame,
    );
  });

  testWidgets(
    'select tool never opens the text dialog (device report regression)',
    (tester) async {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(StudioCanvas));
      await tester.pumpAndSettle();

      // No Add-text dialog; the tap must have been a Select hit-test only
      // (the node at (100,100) may or may not be hit, but no text is added).
      expect(find.text('Add text'), findsNothing);
      expect(controller.objectCount, 1);
      expect(controller.revision, 1);

      // Sanity: switching to Text does open the dialog on a canvas tap.
      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(StudioCanvas));
      await tester.pumpAndSettle();
      expect(find.text('Add text'), findsOneWidget);
    },
  );

  testWidgets('volume down undoes and volume up redoes', (tester) async {
    final controller = StudioController();
    controller.addShapeNode(10, 10);
    await tester.pumpWidget(GgenApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.canUndo, isTrue);
    expect(controller.revision, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.audioVolumeDown);
    await tester.pumpAndSettle();
    expect(controller.revision, 0);
    expect(controller.canRedo, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.audioVolumeUp);
    await tester.pumpAndSettle();
    expect(controller.revision, 1);
  });

  testWidgets('compact toolbar has a working multi-select toggle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(471, 803);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Multi-select off'), findsOneWidget);
    await tester.tap(find.byTooltip('Multi-select off'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Multi-select on'), findsOneWidget);

    // Toggle off again.
    await tester.tap(find.byTooltip('Multi-select on'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Multi-select off'), findsOneWidget);
  });

  testWidgets('delete key removes the whole multi-selection in one step', (
    tester,
  ) async {
    final controller = StudioController();
    controller.addShapeNode(100, 100);
    controller.addShapeNode(400, 100);
    controller.addShapeNode(700, 100);
    await tester.pumpWidget(GgenApp(controller: controller));
    await tester.pumpAndSettle();

    final ids = controller.project.artboards.first.nodes
        .map((n) => n.id)
        .toList();
    controller.selectNode(ids.first, toggle: true);
    controller.selectNode(ids.last, toggle: true);
    await tester.pumpAndSettle();
    expect(controller.objectCount, 3);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(controller.objectCount, 1);
    expect(controller.selectedNodeIds, isEmpty);
    // Single undo restores both deleted nodes.
    controller.undo();
    expect(controller.objectCount, 3);
  });

  testWidgets('project name chip scrolls for long names', (tester) async {
    final longName = 'A very long project name that keeps going and going';
    final controller = StudioController(projectName: longName);
    await tester.pumpWidget(GgenApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text(longName), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CanvasArea),
        matching: find.byType(SingleChildScrollView),
      ),
      findsWidgets,
    );
  });

  group('canvas geometry diagnostics', () {
    testWidgets('animation-size churn logs a bounded number of entries',
        (tester) async {
      debugLog.clear();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      final context = tester.element(find.byType(SizedBox));

      // Simulate a sheet animation: the canvas height changes by 1px per
      // frame (the device export showed ~50 entries in a few seconds).
      for (var i = 0; i < 60; i++) {
        recordCanvasGeometry(context, Size(543, 400.0 + i));
        await tester.pump(const Duration(milliseconds: 600));
      }

      final geometryEntries = debugLog.entries
          .where((entry) => entry.event == 'canvas_geometry')
          .toList();
      // The 8px quantum means 60 one-pixel steps collapse to ~8 quantized
      // sizes; without the fix this would be 60 entries.
      expect(
        geometryEntries.length,
        lessThanOrEqualTo(8),
        reason: 'canvas geometry must be quantized, not logged per frame',
      );
      // Every logged height is a real measured height.
      for (final entry in geometryEntries) {
        final height = entry.details['height'];
        expect(height, isA<int>());
        expect((height as int), inInclusiveRange(400, 459));
      }
    });
  });

  group('file-backed storage wiring', () {
    testWidgets(
      'storage init swaps to the file store and save writes a real file',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final originalPlatform = PathProviderPlatform.instance;
        // Real file I/O (temp dir creation, the save write) never completes
        // in the widget test fake-async zone, so it must run inside
        // tester.runAsync.
        late Directory documents;
        await tester.runAsync(() async {
          documents = await Directory.systemTemp.createTemp('ggen_docs_');
        });
        PathProviderPlatform.instance = _FakePathProvider(documents.path);
        addTearDown(() {
          PathProviderPlatform.instance = originalPlatform;
          if (documents.existsSync()) documents.deleteSync(recursive: true);
        });
        debugLog.clear();

        await tester.pumpWidget(const GgenApp());
        await tester.pumpAndSettle();

        // The swap must succeed without the LateInitializationError that the
        // real device hit (regression: _studio is reassigned in storage init).
        expect(tester.takeException(), isNull);
        expect(
          debugLog.entries.any(
            (entry) =>
                entry.event == 'storage_init' &&
                entry.message == 'File-backed storage initialized',
          ),
          isTrue,
          reason: 'file-backed storage should have initialized',
        );

        // Save must write the canonical .ggen project file into the real
        // documents directory (not just an in-memory map). Trigger the save
        // and let the real async file write complete inside runAsync, then
        // settle the UI (snackbar).
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        // The save itself performs real File I/O, so the tap and the write
        // must run inside runAsync (fake-async never completes file I/O).
        await tester.runAsync(() async {
          await tester.tap(find.text('Save project'));
          await Future<void>.delayed(const Duration(milliseconds: 800));
        });
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();

        final projectsDir = Directory('${documents.path}/projects');
        expect(projectsDir.existsSync(), isTrue);
        final projectFiles = projectsDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.ggen'))
            .toList();
        expect(
          projectFiles,
          isNotEmpty,
          reason: 'save should persist a .ggen file to disk',
        );
        expect(projectFiles.first.readAsStringSync(), contains('"format"'));
      },
    );

    testWidgets('app continues without crash when storage is unavailable', (
      tester,
    ) async {
      // Force MissingPluginException: the in-memory fallback must keep the
      // app fully functional and record a warning.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final originalPlatform = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _ThrowingPathProvider();
      addTearDown(() => PathProviderPlatform.instance = originalPlatform);
      debugLog.clear();
      await tester.pumpWidget(const GgenApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        debugLog.entries.any(
          (entry) => entry.event == 'storage_init' && entry.level == 'warning',
        ),
        isTrue,
        reason: 'unavailable storage must log a warning and fall back',
      );
      expect(find.text('Untitled project'), findsOneWidget);
      // With no stored key, restore must report the clean-install state so
      // exports distinguish it from a restore failure.
      expect(
        debugLog.entries.any(
          (entry) =>
              entry.event == 'project_restore' &&
              entry.level == 'info' &&
              entry.message == 'No prior project stored',
        ),
        isTrue,
        reason: 'no prior project should be recorded in diagnostics',
      );
    });
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

    testWidgets(
      'compact layout has one set of layer and zoom controls (device '
      'report: canvas duplicates the bottom toolbar)',
      (tester) async {
        await pumpAt(tester, const Size(471, 803));
        // Bottom toolbar owns layers/zoom; the floating layers button and
        // the in-canvas zoom overlay must be gone.
        expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
        expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget); // toolbar zoom in
        expect(find.byIcon(Icons.remove), findsOneWidget); // toolbar zoom out
        // And the zoom percentage label must not be rendered at all.
        expect(find.textContaining('%'), findsNothing);
      },
    );

    testWidgets('compact grid toggle flips the artboard grid overlay', (
      tester,
    ) async {
      await pumpAt(tester, const Size(471, 803));
      // One grid control: the bottom toolbar (canvas overlay is hidden on
      // compact, so no second grid icon inside the canvas).
      expect(find.byIcon(Icons.grid_4x4), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ggen_grid_overlay')),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.grid_4x4));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ggen_grid_overlay')),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.grid_4x4));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ggen_grid_overlay')),
        findsOneWidget,
      );
    });

    testWidgets('wide grid toggle flips the artboard grid overlay', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1200, 800));
      // Wide layouts keep the in-canvas zoom overlay, which carries the
      // grid toggle.
      expect(find.byIcon(Icons.grid_4x4), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ggen_grid_overlay')),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.grid_4x4));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ggen_grid_overlay')),
        findsNothing,
      );
    });

    testWidgets('immersive keeps the in-canvas zoom overlay', (tester) async {
      await pumpAt(tester, const Size(471, 803));
      // Enter immersive via the More menu (the top bar is the single
      // entry point for project actions).
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Immersive canvas'));
      await tester.pumpAndSettle();
      // No bottom toolbar in immersive, so the canvas keeps its own zoom
      // controls (single source, not duplicated).
      expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);
      expect(find.textContaining('%'), findsOneWidget);
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
      expect(find.byTooltip('More actions'), findsOneWidget);
    });

    testWidgets('wide inspector can dock left', (tester) async {
      await pumpAt(tester, const Size(1200, 800));
      expect(find.text('Inspector'), findsOneWidget);
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dock inspector'));
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

  testWidgets('layer panel groups and ungroups the selection', (tester) async {
    final controller = StudioController();
    controller.addShapeNode(10, 10);
    controller.addShapeNode(40, 40);
    controller.addShapeNode(70, 70);
    final nodes = controller.project.artboards.first.nodes;
    controller.selectNode(nodes[0].id);
    controller.selectNode(nodes[1].id, toggle: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: LayerPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Group selection'));
    await tester.pumpAndSettle();

    expect(
      controller.project.artboards.first.nodes
          .where((n) => n.kind == DocumentNodeKind.group),
      hasLength(1),
    );
    // Members are listed indented under the group (expanded by default).
    expect(find.text('Shape 1'), findsOneWidget);
    expect(find.text('Shape 2'), findsOneWidget);

    // Ungroup through the header button restores plain top-level layers.
    await tester.tap(find.byTooltip('Ungroup'));
    await tester.pumpAndSettle();
    expect(
      controller.project.artboards.first.nodes
          .where((n) => n.kind == DocumentNodeKind.group),
      isEmpty,
    );
  });

  group('overlay top bar and collapsible canvas toolbar', () {
    testWidgets('pinning an action brings its icon into the top bar', (
      tester,
    ) async {
      await tester.pumpWidget(const GgenApp());
      await tester.pumpAndSettle();

      expect(find.byTooltip('More actions'), findsOneWidget);
      expect(find.byTooltip('New project'), findsNothing);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      final newProjectTile = find.widgetWithText(ListTile, 'New project');
      await tester.tap(
        find.descendant(
          of: newProjectTile,
          matching: find.byTooltip('Show in top bar'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.byTooltip('New project'), findsOneWidget);
    });

    testWidgets(
      'secondary canvas toolbar hides fully (no remnant), mini and expands',
      (tester) async {
        // Real-device size: at 471 the full toolbar fits without scrolling
        // and the 8-row More sheet is fully on-screen.
        tester.view.physicalSize = const Size(471, 1020);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const GgenApp());
        await tester.pumpAndSettle();

        // Full -> hide leaves NOTHING behind (device feedback: a hidden
        // toolbar must not keep a 40px strip).
        expect(find.byTooltip('Hide canvas toolbar'), findsOneWidget);
        expect(find.byTooltip('Undo'), findsOneWidget);
        await tester.tap(find.byTooltip('Hide canvas toolbar'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Hide canvas toolbar'), findsNothing);
        expect(find.byTooltip('Undo'), findsNothing);

        // Restore through the More menu (Canvas toolbar action).
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        await tester.tap(
        find.widgetWithText(ListTile, 'Canvas toolbar'),
      );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Hide canvas toolbar'), findsOneWidget);

        // Full -> mini leaves only the essentials.
        await tester.tap(find.byTooltip('Mini canvas toolbar'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Expand canvas toolbar'), findsOneWidget);
        expect(find.byTooltip('Mini canvas toolbar'), findsNothing);
        expect(find.byTooltip('Zoom in'), findsOneWidget);
        expect(find.byTooltip('Show layers'), findsNothing);

        // Mini -> back to full.
        await tester.tap(find.byTooltip('Expand canvas toolbar'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Mini canvas toolbar'), findsOneWidget);
      },
    );

    testWidgets('canvas toolbar docks to the side and logs the change', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(471, 1020);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      debugLog.clear();
      await tester.pumpWidget(const GgenApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dock canvas toolbar'));
      await tester.pumpAndSettle();

      expect(
        debugLog.entries.any(
          (entry) =>
              entry.event == 'canvas_toolbar_dock' &&
              (entry.details['dock'] == 'left'),
        ),
        isTrue,
        reason: 'first Dock action should move the toolbar to the left',
      );
      // The vertical toolbar is present (its Hide tooltip exists).
      expect(find.byTooltip('Hide canvas toolbar'), findsOneWidget);
    });

    testWidgets('new project creates a portrait artboard from the screen ratio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(471, 1020);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StudioController();
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Portrait');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final artboard = controller.project.artboards.single;
      expect(artboard.width, 1080);
      expect(artboard.height, closeTo(1080 * (1020 / 471), 1.0));
      expect(artboard.height, greaterThan(artboard.width));
    });
  });

  group('inspector text editing', () {
    Future<void> pumpWideWithSelectedText(
      WidgetTester tester,
      StudioController controller,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      controller.addTextNode(100, 120, 'Hello GGEN');
      controller.selectNode(
        controller.project.artboards.first.nodes.single.id,
      );
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'edits content, size and position through one Apply as a single undoable step',
      (tester) async {
        final controller = StudioController();
        await pumpWideWithSelectedText(tester, controller);
        expect(controller.revision, 1); // the add only

        // The inspector shows the node's current payload.
        final contentField = tester.widget<TextField>(
          find.byKey(const ValueKey('inspector_text_content')),
        );
        expect(contentField.controller!.text, 'Hello GGEN');

        await tester.enterText(
          find.byKey(const ValueKey('inspector_text_content')),
          'Edited in inspector',
        );
        await tester.enterText(
          find.byKey(const ValueKey('inspector_text_size')),
          '36',
        );
        await tester.enterText(
          find.byKey(const ValueKey('inspector_text_x')),
          '240',
        );
        await tester.enterText(
          find.byKey(const ValueKey('inspector_text_y')),
          '300',
        );
        await tester.tap(find.byKey(const ValueKey('inspector_text_apply')));
        await tester.pumpAndSettle();

        // One Apply = exactly one new revision through one undoable session.
        expect(controller.revision, 2);
        final geometry = textNodeGeometry(
          controller.project.artboards.first.nodes.single,
        )!;
        expect(geometry.text, 'Edited in inspector');
        expect(geometry.size, 36);
        expect(geometry.x, 240);
        expect(geometry.y, 300);

        // Undo restores the previous payload and the fields resync.
        controller.undo();
        await tester.pumpAndSettle();
        final restored = textNodeGeometry(
          controller.project.artboards.first.nodes.single,
        )!;
        expect(restored.text, 'Hello GGEN');
        expect(restored.size, 24);
        final undoneField = tester.widget<TextField>(
          find.byKey(const ValueKey('inspector_text_content')),
        );
        expect(undoneField.controller!.text, 'Hello GGEN');
      },
    );

    testWidgets('invalid input shows a SnackBar and commits nothing', (
      tester,
    ) async {
      final controller = StudioController();
      await pumpWideWithSelectedText(tester, controller);

      await tester.enterText(
        find.byKey(const ValueKey('inspector_text_content')),
        'Valid content',
      );
      await tester.enterText(
        find.byKey(const ValueKey('inspector_text_size')),
        'not-a-number',
      );
      await tester.tap(find.byKey(const ValueKey('inspector_text_apply')));
      await tester.pump(); // start the SnackBar animation

      expect(
        find.text('Enter valid numbers for Size/X/Y'),
        findsOneWidget,
      );
      expect(controller.revision, 1); // nothing committed
      final geometry = textNodeGeometry(
        controller.project.artboards.first.nodes.single,
      )!;
      expect(geometry.text, 'Hello GGEN');
      expect(geometry.size, 24);

      await tester.pumpAndSettle(); // let the SnackBar timer finish
    });
  });

  group('multi-column text frame layout', () {
    testWidgets('wide inspector applies columns and gutter, shows guides',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StudioController();
      controller.addTextNode(100, 120,
          'One two three four five six seven eight nine ten eleven twelve '
          'thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty');
      final id = controller.project.artboards.first.nodes.single.id;
      controller.selectNode(id);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();

      expect(controller.revision, 1);
      // A selected frame always shows column guides (solid border when
      // selected, dashed otherwise; visible for columns>1 too).
      expect(find.byKey(ValueKey('ggen_text_frame_guides_${id.value}')),
          findsOneWidget);

      // Set 2 columns through the controller, then exercise the gutter field
      // and Apply button through the inspector (sliders are dragged, not
      // tapped, so this keeps the assertion deterministic while still
      // exercising the Apply path and the gutter text field).
      controller.configureTextColumns(id, columnCount: 2, gutter: 0);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('inspector_gutter')),
        '12',
      );
      await tester.tap(
        find.byKey(const ValueKey('inspector_columns_apply')),
      );
      await tester.pumpAndSettle();

      expect(textNodeColumnCount(
          controller.project.artboards.first.nodes.single), 2);
      expect(
        textNodeGutter(controller.project.artboards.first.nodes.single),
        12,
      );

      // Column 0 text renders as a real Text widget, and the flow engine
      // computed two column bounds (col1 may be empty if text fits in col0).
      expect(
        find.byKey(ValueKey('ggen_text_frame_${id.value}_col0')),
        findsOneWidget,
      );
      final flowed = flowTextFrame(
          controller.project.artboards.first.nodes.single);
      expect(flowed, isNotNull);
      expect(flowed!.allColumns.length, 2);
      expect(flowed.conserves(
          controller.project.artboards.first.nodes.single.extensions['text']
              as String),
          isTrue);

      // Reset returns to one column.
      await tester.tap(find.byKey(const ValueKey('inspector_columns_reset')));
      await tester.pumpAndSettle();
      expect(textNodeColumnCount(
          controller.project.artboards.first.nodes.single), 1);
    });

    testWidgets('column change is one undo/redo step', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StudioController();
      controller.addTextNode(100, 120, 'Hello columns');
      final id = controller.project.artboards.first.nodes.single.id;
      controller.selectNode(id);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();
      final before = controller.revision;

      // Commit columns through the inspector Apply (gutter field + Apply).
      await tester.enterText(
        find.byKey(const ValueKey('inspector_gutter')),
        '8',
      );
      await tester.tap(
        find.byKey(const ValueKey('inspector_columns_apply')),
      );
      await tester.pumpAndSettle();
      expect(controller.revision, before + 1);

      // Volume-down undoes the single column transaction.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.audioVolumeDown);
      await tester.pumpAndSettle();
      expect(controller.revision, before);
      expect(textNodeGutter(
          controller.project.artboards.first.nodes.single), 0);
      // Volume-up redoes.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.audioVolumeUp);
      await tester.pumpAndSettle();
      expect(textNodeGutter(
          controller.project.artboards.first.nodes.single), 8);
    });

    testWidgets('slider changes column count and Apply commits it',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StudioController();
      controller.addTextNode(100, 120, 'Slider columns');
      final id = controller.project.artboards.first.nodes.single.id;
      controller.selectNode(id);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();

      // Drag the slider to the right (exact magnitude is platform-dependent,
      // so assert it moved off 1 rather than a precise column count), then
      // Apply and verify the committed count matches the slider's value.
      final sliderFinder =
          find.byKey(const ValueKey('inspector_columns_slider'));
      await tester.drag(sliderFinder, const Offset(120, 0));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(sliderFinder);
      final expected = slider.value.round();
      expect(expected, greaterThan(1));

      await tester.tap(
        find.byKey(const ValueKey('inspector_columns_apply')),
      );
      await tester.pumpAndSettle();
      expect(textNodeColumnCount(
          controller.project.artboards.first.nodes.single), expected);
    });

    testWidgets(
        'compact 471px viewport opens column sheet and applies columns',
        (tester) async {
      tester.view.physicalSize = const Size(471, 1020);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StudioController();
      controller.addTextNode(100, 120, 'Mobile column test');
      final id = controller.project.artboards.first.nodes.single.id;
      // Select via Select tool + canvas tap.
      controller.selectNode(id);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();

      // The compact Columns destination is enabled (a text frame is selected).
      final columnsDest = find.text('Columns');
      expect(columnsDest, findsOneWidget);
      await tester.ensureVisible(columnsDest);
      await tester.tap(columnsDest);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mobile_columns_slider')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('mobile_gutter_field')),
          findsOneWidget);

      // Enter a gutter and drag the slider to the right, then Apply. The
      // slider applies live; read its final value rather than asserting a
      // precise count (drag magnitude is platform-dependent).
      await tester.enterText(
        find.byKey(const ValueKey('mobile_gutter_field')),
        '10',
      );
      final sliderFinder =
          find.byKey(const ValueKey('mobile_columns_slider'));
      await tester.drag(sliderFinder, const Offset(120, 0));
      await tester.pumpAndSettle();
      final expected =
          tester.widget<Slider>(sliderFinder).value.round();
      expect(expected, greaterThan(1));

      await tester.tap(find.byKey(const ValueKey('mobile_columns_apply')));
      await tester.pumpAndSettle();

      final node = controller.project.artboards.first.nodes.single;
      expect(textNodeColumnCount(node), expected);
      expect(textNodeGutter(node), 10);
    });

    testWidgets('overflow tab and guides render when text exceeds frame',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StudioController();
      // Build a deliberately small frame (120x48) holding long text so the
      // flow reports terminal overflow and the red corner tab is painted.
      final project = controller.project;
      final artboard = project.artboards.first;
      final smallFrame = DocumentNode(
        id: GgenId('text-small'),
        kind: DocumentNodeKind.textFrame,
        name: 'Overflow',
        extensions: <String, Object?>{
          'x': 100.0,
          'y': 120.0,
          'w': 120.0,
          'h': 48.0,
          'size': 16.0,
          'text': 'One two three four five six seven eight nine ten eleven twelve',
          'color': 0xFF222222,
          'columns': 1,
          'gutter': 0.0,
        },
      );
      final next = project.copyWith(
        revision: project.revision,
        artboards: <Artboard>[
          Artboard(
            id: artboard.id,
            name: artboard.name,
            width: artboard.width,
            height: artboard.height,
            nodes: <DocumentNode>[smallFrame],
          ),
        ],
      );
      final session = controller.beginSession();
      session.updatePreview(next);
      controller.commitSession(session, 'Add overflow frame');
      controller.selectNode(smallFrame.id);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();

      final node = controller.project.artboards.first.nodes.single;
      final result = flowTextFrame(node);
      expect(result, isNotNull);
      final story = (node.extensions['text'] as String);
      expect(result!.conserves(story), isTrue);
      expect(result.hasOverflow, isTrue,
          reason: 'the small frame cannot hold the long text');
      // Guides overlay is present for the selected frame.
      expect(
        find.byKey(ValueKey('ggen_text_frame_guides_${node.id.value}')),
        findsOneWidget,
      );
    });
  });

  group('linked text flow UI', () {
    testWidgets(
        'wide inspector links and unlinks a text frame with one undo step each',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StudioController();
      controller.addTextNode(100, 120, 'First story');
      controller.addTextNode(560, 120, 'Second story');
      final nodes = controller.project.artboards.first.nodes;
      final a = nodes[0].id;
      final b = nodes[1].id;
      controller.selectNode(a);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();

      // The Text flow section offers the other frame as a link candidate.
      expect(find.text('Text flow'), findsOneWidget);
      expect(
        find.byKey(ValueKey('inspector_flow_link_${b.value}')),
        findsOneWidget,
      );
      final before = controller.revision;

      // Link: one undoable revision; the section flips to the linked state.
      // The flow section can sit below the fold of the scrollable inspector.
      await tester
          .ensureVisible(find.byKey(ValueKey('inspector_flow_link_${b.value}')));
      await tester.tap(find.byKey(ValueKey('inspector_flow_link_${b.value}')));
      await tester.pumpAndSettle();
      expect(controller.revision, before + 1);
      expect(textFrameSuccessor(nodeOf(controller, a)), b.value);
      expect(find.text('Flows into: ${nodes[1].name}'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inspector_flow_unlink')),
        findsOneWidget,
      );

      // Undo removes the link (one step); redo restores it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.audioVolumeDown);
      await tester.pumpAndSettle();
      expect(textFrameSuccessor(nodeOf(controller, a)), isNull);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.audioVolumeUp);
      await tester.pumpAndSettle();
      expect(textFrameSuccessor(nodeOf(controller, a)), b.value);

      // Unlink: one undoable revision back to the unlinked state.
      final beforeUnlink = controller.revision;
      await tester
          .ensureVisible(find.byKey(const ValueKey('inspector_flow_unlink')));
      await tester.tap(find.byKey(const ValueKey('inspector_flow_unlink')));
      await tester.pumpAndSettle();
      expect(controller.revision, beforeUnlink + 1);
      expect(textFrameSuccessor(nodeOf(controller, a)), isNull);
      expect(
        find.byKey(ValueKey('inspector_flow_link_${b.value}')),
        findsOneWidget,
      );
    });

    testWidgets(
        'compact Columns sheet shows live link/unlink controls for text frames',
        (tester) async {
      tester.view.physicalSize = const Size(471, 1020);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StudioController();
      controller.addTextNode(100, 120, 'First story');
      controller.addTextNode(560, 120, 'Second story');
      final nodes = controller.project.artboards.first.nodes;
      final a = nodes[0].id;
      final b = nodes[1].id;
      controller.selectNode(a);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();

      // The sheet offers the link action next to the column controls.
      expect(find.byKey(const ValueKey('mobile_columns_slider')),
          findsOneWidget);
      expect(
        find.byKey(ValueKey('mobile_flow_link_${b.value}')),
        findsOneWidget,
      );
      final before = controller.revision;

      // Linking from the sheet updates the sheet live (it stays open).
      await tester.tap(find.byKey(ValueKey('mobile_flow_link_${b.value}')));
      await tester.pumpAndSettle();
      expect(controller.revision, before + 1);
      expect(textFrameSuccessor(nodeOf(controller, a)), b.value);
      expect(find.text('Flows into: ${nodes[1].name}'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile_flow_unlink')),
        findsOneWidget,
      );

      // Unlink from the sheet returns to the candidate list, live.
      await tester.tap(find.byKey(const ValueKey('mobile_flow_unlink')));
      await tester.pumpAndSettle();
      expect(textFrameSuccessor(nodeOf(controller, a)), isNull);
      expect(
        find.byKey(ValueKey('mobile_flow_link_${b.value}')),
        findsOneWidget,
      );
    });
  });
}

/// Finds [id] in the first artboard (widget-test convenience).
DocumentNode nodeOf(StudioController controller, GgenId id) =>
    controller.project.artboards.first.nodes
        .firstWhere((n) => n.id == id);
