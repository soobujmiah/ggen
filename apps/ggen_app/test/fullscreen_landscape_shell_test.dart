import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_app/src/workspace/workspace_bars.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fullscreen (immersive) free-form control clusters and the landscape
/// device-class layout (2026-08-25 plan: `docs/architecture/fullscreen-
/// control-and-landscape-plan.md`, superseded by the free-form placement
/// milestone).
///
/// Pins:
/// - landscape phones (800×360, 640×360) get ONE compact landscape bar and
///   no left rail / status bar / fixed zoom overlay (maximum usable canvas);
/// - wide (1280×800) keeps the rail + status bar + zoom overlay;
/// - immersive renders only the user's free-form floating control clusters
///   (default top bar and legacy fixed zoom overlay gone), with an enforced
///   exit control;
/// - cluster positions persist through `workspace.fullscreen_clusters`
///   (normalized x/y, no region snapping); overlapping clusters all render;
/// - idle clusters fade in place after `kFullscreenIdleTimeout` and restore
///   on interaction;
/// - orientation changes preserve tool/grid state.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugLog.clear();
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size logical, {
    StudioController? controller,
  }) async {
    tester.view.physicalSize = logical;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GgenApp(controller: controller));
    await tester.pumpAndSettle();
  }

  Future<void> enterImmersive(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    // The More sheet is capped at 9/16 of the screen height, so on short
    // viewports (e.g. 800×600 landscape) the Immersive row sits below the
    // fold. The action rows live in the sheet's lazily-built reorderable
    // list — scroll until the row is built and visible, then tap it.
    final immersiveRow = find.text('Immersive canvas');
    await tester.scrollUntilVisible(
      immersiveRow,
      60,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(immersiveRow);
    await tester.pumpAndSettle();
  }

  group('landscape device class', () {
    testWidgets('landscape phone (800×360): one compact bar, no rail, no '
        'status bar, no zoom overlay', (tester) async {
      await pumpAt(tester, const Size(800, 360));
      expect(find.byKey(LandscapeBar.barKey), findsOneWidget);
      expect(find.byKey(MobileToolRail.railKey), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(StatusBar), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape phone (640×360) fits without overflow',
        (tester) async {
      await pumpAt(tester, const Size(640, 360));
      expect(find.byKey(LandscapeBar.barKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape bar exposes tools, history and zoom',
        (tester) async {
      await pumpAt(tester, const Size(800, 360));
      expect(find.byTooltip('Rectangle'), findsOneWidget);
      expect(find.byTooltip('Select'), findsOneWidget);
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Fit to screen'), findsOneWidget);
    });

    testWidgets('wide (1280×800) keeps rail, status bar and zoom overlay',
        (tester) async {
      await pumpAt(tester, const Size(1280, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(StatusBar), findsOneWidget);
      expect(find.byKey(LandscapeBar.barKey), findsNothing);
      expect(find.textContaining('%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('portrait phone (471×1020) keeps the canonical compact shell',
        (tester) async {
      await pumpAt(tester, const Size(471, 1020));
      expect(find.byKey(MobileToolRail.railKey), findsOneWidget);
      expect(find.byKey(ContextualActionBar.barKey), findsOneWidget);
      expect(find.byKey(LandscapeBar.barKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('orientation change preserves tool and grid state',
        (tester) async {
      await pumpAt(tester, const Size(400, 800));
      // Select the Rectangle tool and toggle the grid off (grid starts on,
      // so the button reads "Hide grid" until tapped).
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide grid'));
      await tester.pumpAndSettle();

      // Rotate to landscape: same shell state, different layout class.
      await pumpAt(tester, const Size(800, 360));
      expect(find.byKey(LandscapeBar.barKey), findsOneWidget);
      // Rectangle still selected (filled selected icon) on the landscape bar.
      expect(find.byIcon(Icons.rectangle), findsOneWidget);
      // Grid still off (tooltip means "grid hidden").
      expect(find.byTooltip('Show grid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('fullscreen free-form control clusters', () {
    testWidgets('immersive renders only the default clusters', (tester) async {
      await pumpAt(tester, const Size(471, 1020));
      await enterImmersive(tester);

      // Default top-right document cluster (with the enforced exit control).
      expect(find.byTooltip('Immersive canvas'), findsOneWidget);
      expect(find.byTooltip('Open project'), findsOneWidget);
      expect(find.byTooltip('Save project'), findsOneWidget);
      expect(find.byTooltip('New project'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);

      // Default bottom-right history + zoom cluster.
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Redo'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      expect(find.byTooltip('Fit to screen'), findsOneWidget);
      expect(find.byTooltip('Grid'), findsOneWidget);

      // Default bottom-left context cluster.
      expect(find.byTooltip('Layers'), findsOneWidget);
      expect(find.byTooltip('Multi-select'), findsOneWidget);
      expect(find.byTooltip('Columns'), findsOneWidget);

      // Default chrome is gone in fullscreen.
      expect(find.byTooltip('More actions'), findsNothing);
      expect(find.byKey(ContextualActionBar.barKey), findsNothing);
      expect(find.byKey(LandscapeBar.barKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('customizing a control placement persists to preferences',
        (tester) async {
      await pumpAt(tester, const Size(471, 1020));
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customize fullscreen controls'));
      await tester.pumpAndSettle();

      // Move Layers out of the default tools group into a NEW group.
      final tile = find.ancestor(
        of: find.text('Layers'),
        matching: find.byType(ListTile),
      );
      final popup = find.descendant(
        of: tile,
        matching: find.byType(PopupMenuButton<String?>),
      );
      await tester.tap(popup);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New group…').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('workspace.fullscreen_clusters');
      expect(stored, isNotNull);
      expect(stored, contains('"group1"'));
      expect(stored, contains('"layers"'));

      // Close the sheet, enter immersive, and the moved control is present.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await enterImmersive(tester);
      expect(find.byTooltip('Layers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fullscreen undo is disabled without history and enabled '
        'after an edit', (tester) async {
      final controller = StudioController();
      await pumpAt(
        tester,
        const Size(471, 1020),
        controller: controller,
      );
      await enterImmersive(tester);
      // Undo without history: button visible but disabled.
      IconButton undoButton() => tester.widget<IconButton>(
        find.descendant(
          of: find.byTooltip('Undo'),
          matching: find.byType(IconButton),
        ),
      );
      expect(undoButton().onPressed, isNull);

      // Add a shape through the injected controller, then undo works.
      controller.addShapeNode(10, 10);
      await tester.pumpAndSettle();
      expect(undoButton().onPressed, isNotNull);
    });

    testWidgets('dragging a fullscreen cluster moves it freely (no snapping) '
        'and persists the new position', (tester) async {
      await pumpAt(tester, const Size(800, 600));
      await enterImmersive(tester);

      // Grab the bottom-right history cluster and drag it to the middle.
      final zoomIn = find.byTooltip('Zoom in');
      expect(zoomIn, findsOneWidget);
      final center = tester.getCenter(zoomIn);
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 700));
      // Two-step move: the first update establishes the drag origin, the
      // second determines the free-form drop position.
      await gesture.moveBy(const Offset(-100, -100));
      await tester.pump();
      await gesture.moveBy(const Offset(-200, -200));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('workspace.fullscreen_clusters');
      expect(stored, isNotNull);
      // Free-form position: the history cluster no longer sits at its
      // default bottom-right anchor, and no region names exist anymore.
      expect(stored, isNot(contains('"x":1.0,"y":1.0')));
      expect(stored, isNot(contains('topLeft')));
      expect(stored, isNot(contains('bottomRight')));
      // The cluster is still rendered (never hidden by the move).
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlapping clusters both render and stay independently '
        'movable', (tester) async {
      // Seed a saved layout with two clusters at the SAME position.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_clusters':
            '{"clusters":['
            '{"id":"document","x":0.5,"y":0.5,'
            '"controls":["save","newProject","settings"]},'
            '{"id":"history","x":0.5,"y":0.5,'
            '"controls":["undo","redo","zoomIn","zoomOut","zoomFit","grid"]}'
            ']}',
      });
      await pumpAt(tester, const Size(800, 600));
      await enterImmersive(tester);

      // BOTH clusters render at the same spot — neither one disappears.
      expect(find.byTooltip('Save project'), findsOneWidget);
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);

      // Drag the history cluster away; both clusters survive independently.
      final zoomIn = find.byTooltip('Zoom in');
      final center = tester.getCenter(zoomIn);
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(-50, -50));
      await tester.pump();
      await gesture.moveBy(const Offset(-250, -200));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Save project'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      final stored = (await SharedPreferences.getInstance())
          .getString('workspace.fullscreen_clusters');
      expect(stored, contains('"history"'));
      expect(stored, contains('"document"'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fullscreen controls fade when idle and restore on '
        'interaction, without relocating', (tester) async {
      await pumpAt(tester, const Size(471, 1020));
      await enterImmersive(tester);

      AnimatedOpacity documentOpacity() => tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('fullscreen_cluster_document')),
      );
      final before = tester.getTopLeft(find.byTooltip('Save project'));

      // Fully prominent immediately after entering immersive.
      expect(documentOpacity().opacity, 1);

      // After the idle timeout the controls are subdued IN PLACE.
      await tester.pump(kFullscreenIdleTimeout);
      await tester.pumpAndSettle();
      expect(documentOpacity().opacity, kFullscreenIdleOpacity);
      expect(tester.getTopLeft(find.byTooltip('Save project')), before);

      // Any interaction restores full prominence.
      await tester.tap(find.byTooltip('Grid'));
      await tester.pumpAndSettle();
      expect(documentOpacity().opacity, 1);
      expect(tester.getTopLeft(find.byTooltip('Save project')), before);

      // And the idle timer arms again after interaction.
      await tester.pump(kFullscreenIdleTimeout);
      await tester.pumpAndSettle();
      expect(documentOpacity().opacity, kFullscreenIdleOpacity);
      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape defaults place clusters on the LEFT and RIGHT '
        'sides with the center free for canvas', (tester) async {
      await pumpAt(tester, const Size(800, 360));
      await enterImmersive(tester);

      // Never-customized defaults in landscape: ONE tool/navigation cluster
      // on the left side, ONE action cluster on the right side.
      final tools = tester.getTopLeft(
        find.byKey(const ValueKey('fullscreen_cluster_positioned_tools')),
      );
      final actions = tester.getTopLeft(
        find.byKey(const ValueKey('fullscreen_cluster_positioned_actions')),
      );
      expect(tools.dx, lessThan(30), reason: 'tools cluster hugs the left');
      expect(
        actions.dx,
        greaterThan(500),
        reason: 'actions cluster on the right',
      );
      // Vertically centered in the available space, not glued to an edge.
      expect(tools.dy, greaterThan(60));
      expect(tools.dy, lessThan(300));
      expect(actions.dy, greaterThan(60));
      expect(actions.dy, lessThan(300));

      // LEFT: primary tool/navigation cluster. RIGHT: actions incl. the
      // guaranteed immersive exit.
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Fit to screen'), findsOneWidget);
      expect(find.byTooltip('Layers'), findsOneWidget);
      expect(find.byTooltip('Save project'), findsOneWidget);
      expect(find.byTooltip('New project'), findsOneWidget);
      expect(find.byTooltip('Multi-select'), findsOneWidget);
      expect(find.byTooltip('Immersive canvas'), findsOneWidget);

      // No cluster occupies the center strip between the sides.
      final occupiedX = <double>[tools.dx, actions.dx];
      expect(
        occupiedX.any((x) => x > 260 && x < 460),
        isFalse,
        reason: 'center stays maximum canvas',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('portrait defaults keep the corner arrangement unchanged',
        (tester) async {
      await pumpAt(tester, const Size(471, 1020));
      await enterImmersive(tester);

      final document = tester.getTopLeft(
        find.byKey(const ValueKey('fullscreen_cluster_positioned_document')),
      );
      final history = tester.getTopLeft(
        find.byKey(const ValueKey('fullscreen_cluster_positioned_history')),
      );
      final tools = tester.getTopLeft(
        find.byKey(const ValueKey('fullscreen_cluster_positioned_tools')),
      );
      // document: top-right corner.
      expect(document.dy, lessThan(30));
      expect(document.dx, greaterThan(200));
      // history: bottom-right corner.
      expect(history.dy, greaterThan(800));
      expect(history.dx, greaterThan(150));
      // tools: bottom-left corner.
      expect(tools.dy, greaterThan(800));
      expect(tools.dx, lessThan(30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rotating after a drag keeps the cluster inside the new '
        'viewport (normalized position recovers)', (tester) async {
      await pumpAt(tester, const Size(471, 1020));
      await enterImmersive(tester);

      // Drag the bottom-right history cluster toward the MIDDLE of the
      // portrait canvas (a mid-screen target, not a corner, so the pixel
      // position genuinely differs across orientations).
      final zoomIn = find.byTooltip('Zoom in');
      final gesture = await tester.startGesture(tester.getCenter(zoomIn));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(-50, -200));
      await tester.pump();
      await gesture.moveBy(const Offset(-55, -268));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.byTooltip('Zoom in'));

      // Rotate to landscape: the persisted NORMALIZED position re-clamps
      // into the new viewport — the cluster must stay fully reachable.
      await pumpAt(tester, const Size(800, 360));
      final after = tester.getTopLeft(find.byTooltip('Zoom in'));
      expect(after.dx, greaterThanOrEqualTo(0));
      expect(after.dy, greaterThanOrEqualTo(0));
      expect(after.dx, lessThan(800));
      expect(after.dy, lessThan(360));
      expect(before, isNot(after), reason: 'viewport changed, so pixels move');
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging a subdued (idle) cluster restores full prominence',
        (tester) async {
      await pumpAt(tester, const Size(471, 1020));
      await enterImmersive(tester);

      AnimatedOpacity documentOpacity() => tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('fullscreen_cluster_document')),
      );
      await tester.pump(kFullscreenIdleTimeout);
      await tester.pumpAndSettle();
      expect(documentOpacity().opacity, kFullscreenIdleOpacity);

      // Long-press-drag the subdued document cluster: it restores full
      // prominence immediately and stays prominent after the drop.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Save project')),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(-120, -120));
      await tester.pump(const Duration(milliseconds: 100));
      expect(documentOpacity().opacity, 1);
      await gesture.moveBy(const Offset(-160, -160));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(documentOpacity().opacity, 1);

      // The cluster moved (free-form) and persisted.
      final stored = (await SharedPreferences.getInstance())
          .getString('workspace.fullscreen_clusters');
      expect(stored, isNotNull);
      expect(stored, contains('"document"'));
      expect(tester.takeException(), isNull);
    });
  });
}
