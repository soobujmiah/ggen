import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
import 'package:ggen_app/src/workspace/control_layout.dart';
import 'package:ggen_app/src/workspace/workspace_bars.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fullscreen (immersive) control regions and the landscape device-class
/// layout (2026-08-25 plan: `docs/architecture/fullscreen-control-and-
/// landscape-plan.md`).
///
/// Pins:
/// - landscape phones (800×360, 640×360) get ONE compact landscape bar and
///   no left rail / status bar / fixed zoom overlay (maximum usable canvas);
/// - wide (1280×800) keeps the rail + status bar + zoom overlay;
/// - immersive renders only the user's chosen control regions (default top
///   bar and legacy fixed zoom overlay gone), with an enforced exit control;
/// - customization persists through `workspace.fullscreen_regions`;
/// - orientation changes preserve tool/grid state.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugLog.clear();
  });

  Future<void> pumpAt(WidgetTester tester, Size logical) async {
    tester.view.physicalSize = logical;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    await tester.pumpAndSettle();
  }

  Future<void> enterImmersive(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Immersive canvas'));
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

  group('fullscreen control regions', () {
    testWidgets('immersive renders only the default region clusters',
        (tester) async {
      await pumpAt(tester, const Size(471, 1020));
      await enterImmersive(tester);

      // Default top-right document cluster (with the enforced exit control).
      expect(find.byTooltip('Immersive canvas'), findsOneWidget);
      expect(find.byTooltip('Save project'), findsOneWidget);
      expect(find.byTooltip('New project'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);

      // Default bottom-right history + movable zoom cluster.
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

      // Move Layers from bottom-left to top-left.
      final tile = find.ancestor(
        of: find.text('Layers'),
        matching: find.byType(ListTile),
      );
      final popup = find.descendant(
        of: tile,
        matching: find.byType(PopupMenuButton<ControlRegion?>),
      );
      await tester.tap(popup);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top-left').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('workspace.fullscreen_regions');
      expect(stored, isNotNull);
      expect(stored, contains('"topLeft"'));
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
      await pumpAt(tester, const Size(471, 1020));
      await enterImmersive(tester);
      // Undo without history: button visible but disabled.
      final undoButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Undo'),
          matching: find.byType(IconButton),
        ),
      );
      expect(undoButton.onPressed, isNull);

      // Add a shape via the controller through the canvas, then undo works.
      final controller = (tester.widget<GgenApp>(find.byType(GgenApp)))
          .controller!;
      controller.addShapeNode(10, 10);
      await tester.pumpAndSettle();
      final enabledUndo = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Undo'),
          matching: find.byType(IconButton),
        ),
      );
      expect(enabledUndo.onPressed, isNotNull);
    });

    testWidgets('dragging a fullscreen cluster snaps and persists the region',
        (tester) async {
      await pumpAt(tester, const Size(800, 600));
      await enterImmersive(tester);

      // Grab the bottom-right zoom cluster and drag it far to the top-left.
      final zoomIn = find.byTooltip('Zoom in');
      expect(zoomIn, findsOneWidget);
      final center = tester.getCenter(zoomIn);
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 700));
      // From the bottom-right cluster (~778,570) to the top-left quadrant
      // (<266, <300) of the 800×600 viewport.
      await gesture.moveBy(const Offset(-560, -350));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('workspace.fullscreen_regions');
      expect(stored, isNotNull);
      expect(stored, contains('"topLeft"'));
      expect(stored, contains('"zoomIn"'));
      expect(tester.takeException(), isNull);
    });
  });
}
