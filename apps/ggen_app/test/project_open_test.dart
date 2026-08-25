import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_app/src/storage/file_project_store.dart';
import 'package:ggen_app/src/storage/memory_project_store.dart';
import 'package:ggen_app/workspace_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Open/Load project: the file-backed store already supported save +
/// startup restore; these tests pin the NEW user-facing open flow:
/// - saved projects are discoverable through the existing store (no second
///   persistence system);
/// - opening one restores its state through the existing restore path;
/// - missing/corrupt projects fail safely (workspace untouched);
/// - the last-project key survives unrelated workspace changes (startup
///   restore can never silently lose the project);
/// - an empty store shows a friendly empty state.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugLog.clear();
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    StudioController? controller,
  }) async {
    tester.view.physicalSize = const Size(471, 1020);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GgenApp(controller: controller));
    await tester.pumpAndSettle();
  }

  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
  }

  testWidgets('Open project lists saved projects and opens the chosen one', (
    tester,
  ) async {
    final store = MemoryProjectStore();
    final controller = StudioController(store: store);
    controller.newProject('Alpha');
    controller.addShapeNode(10, 10);
    await controller.save();
    final alphaKey = controller.storageKey.value;
    controller.newProject('Beta');
    await controller.save();

    await pumpShell(tester, controller: controller);
    // The current project is Beta (shown by the canvas project-name chip).
    expect(find.text('Beta'), findsOneWidget);

    await openMore(tester);
    await tester.tap(find.text('Open project'));
    await tester.pumpAndSettle();

    // Both saved projects are listed, most recently updated first.
    expect(find.widgetWithText(ListTile, 'Alpha'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Beta'), findsOneWidget);
    expect(
      tester.getTopLeft(find.widgetWithText(ListTile, 'Beta')).dy,
      lessThan(tester.getTopLeft(find.widgetWithText(ListTile, 'Alpha')).dy),
    );

    // Open Alpha: the project state is restored through the SAME store
    // restore path startup uses, and the key is remembered.
    await tester.tap(find.widgetWithText(ListTile, 'Alpha'));
    await tester.pumpAndSettle();
    expect(controller.project.name, 'Alpha');
    expect(controller.revision, 1);
    expect(find.text('Opened "Alpha"'), findsOneWidget);
    final prefs = await WorkspacePreferences.load();
    expect(prefs.lastProjectKey, alphaKey);
    // Let the snackbar timer expire so nothing is left pending.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty store shows a friendly empty state', (tester) async {
    await pumpShell(tester, controller: StudioController());
    await openMore(tester);
    await tester.tap(find.text('Open project'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved projects yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing project fails safely and leaves the workspace '
      'untouched', (tester) async {
    // Real file IO must run in the real async zone (fake async would
    // deadlock on the IO futures).
    Directory? root;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('ggen_open_test_');
    });
    final dir = root!;
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final store = FileProjectStore(dir);
    final controller = StudioController(store: store);
    controller.newProject('Vault');
    controller.addShapeNode(5, 5);
    await tester.runAsync(() => controller.save());

    await pumpShell(tester, controller: controller);
    await openMore(tester);
    await tester.tap(find.text('Open project'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Vault'), findsOneWidget);

    // The stored file disappears (external removal) AFTER listing.
    final projectsDir = Directory('${dir.path}/projects');
    final stored = projectsDir.listSync().whereType<File>().single;
    stored.deleteSync();

    await tester.tap(find.widgetWithText(ListTile, 'Vault'));
    await tester.pumpAndSettle();
    // Fail-safe: nothing opened, the workspace is untouched, and the
    // condition is user-visible.
    expect(find.text('Project missing or corrupt — nothing opened'), findsOneWidget);
    expect(controller.project.name, 'Vault');
    expect(controller.revision, 1);
    expect(controller.objectCount, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the last-project key survives unrelated workspace changes', (
    tester,
  ) async {
    final store = MemoryProjectStore();
    final controller = StudioController(store: store);
    controller.newProject('Kept');
    await controller.save();
    final keptKey = controller.storageKey.value;

    await pumpShell(tester, controller: controller);
    // Save through the UI (sets the last-project key).
    await openMore(tester);
    await tester.tap(find.text('Save project'));
    await tester.pumpAndSettle();
    expect((await WorkspacePreferences.load()).lastProjectKey, keptKey);
    // Dismiss the sheet, then make an unrelated workspace change: pin an
    // action to the top bar (persists the whole workspace).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await openMore(tester);
    final pin = find.descendant(
      of: find.ancestor(
        of: find.text('Save project'),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(IconButton),
    ).first;
    await tester.tap(pin);
    await tester.pumpAndSettle();

    // The project key is still there — startup restore will still work.
    expect((await WorkspacePreferences.load()).lastProjectKey, keptKey);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
