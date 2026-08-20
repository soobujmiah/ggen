import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
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

  testWidgets('canvas-first switch toggles and reflects taps', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    await tester.pumpAndSettle();

    // Open the workspace settings sheet via the compact Settings tab.
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
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Save project'));
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
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
