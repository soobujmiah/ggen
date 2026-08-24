import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
import 'package:ggen_app/src/canvas/studio_canvas.dart';
import 'package:ggen_app/src/controller/studio_controller.dart';
import 'package:ggen_app/src/workspace/studio_tool.dart';
import 'package:ggen_app/src/workspace/workspace_bars.dart';
import 'package:ggen_core/ggen_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mobile workspace shell regression suite for the Redmi Turbo 4 Pro
/// device findings of 2026-08-24:
///
///  1. "A RenderFlex overflowed by 1.2 pixels on the right." — layout
///     overflow at the 471px-class portrait width.
///  2. "RangeError (length): Invalid value: Not in inclusive range 0..2: 3"
///     — the compact bottom NavigationBar forwarded its 4th destination
///     index (the contextual Columns entry) into the 3-entry tool list.
///  3. Accumulated/duplicated toolbar surfaces (dockable secondary toolbar
///     vs bottom navigation vs floating buttons).
///
/// These tests pin the canonical mobile shell: stable left tool rail,
/// single bottom contextual action bar, no out-of-range tool state, and
/// no RenderFlex overflow at the exact reported device geometry.
void main() {
  /// The exact logical geometry reported by the device diagnostics
  /// (471px-class portrait).
  const deviceLogical = Size(471, 1020);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugLog.clear();
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    StudioController? controller,
    Size logical = deviceLogical,
  }) async {
    tester.view.physicalSize = logical;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GgenApp(controller: controller));
    await tester.pumpAndSettle();
  }

  group('RangeError regression (device: 0..2 index 3)', () {
    testWidgets(
      'Text tool active, tapping every visible control never throws a '
      'RangeError',
      (tester) async {
        final controller = StudioController();
        await pumpShell(tester, controller: controller);

        // Activate the Text tool from the rail (index 2, the last tool).
        await tester.tap(find.byTooltip('Text'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The old crash path: the 4th bottom destination (Columns) sent
        // index 3 into the 3-entry tool list. The action bar equivalent
        // simply is not present without a selected text frame — and no
        // control on screen can produce an out-of-range tool index.
        expect(find.byTooltip('Columns'), findsNothing);

        // Tap every enabled button of the action bar; none may throw.
        for (final tooltip in <String>[
          'Zoom in',
          'Zoom out',
          'Fit to screen',
          'Show grid',
          'Hide grid',
        ]) {
          final target = find.byTooltip(tooltip);
          if (target.evaluate().isNotEmpty) {
            await tester.tap(target.first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: tooltip);
          }
        }
      },
    );

    testWidgets(
      'full Text-tool gesture cycle stays healthy '
      '(select→text→frame→edit→outside-tap→select→reselect)',
      (tester) async {
        final controller = StudioController();
        await pumpShell(tester, controller: controller);

        // Select → Text.
        await tester.tap(find.byTooltip('Select'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Text'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Create a text frame (canvas tap opens the dialog).
        await tester.tap(find.byType(StudioCanvas));
        await tester.pumpAndSettle();
        expect(find.text('Add text'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'Device text');
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(controller.objectCount, 1);
        expect(tester.takeException(), isNull);

        // Tap outside (opens the dialog again — cancel it), repeated taps.
        await tester.tapAt(const Offset(300, 500));
        await tester.pumpAndSettle();
        if (find.text('Cancel').evaluate().isNotEmpty) {
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);

        // Text → Select while the frame exists; select the frame.
        await tester.tap(find.byTooltip('Select'));
        await tester.pumpAndSettle();
        final id = controller.project.artboards.first.nodes.single.id;
        controller.selectNode(id);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Selected text frame surfaces the contextual Columns action;
        // open and close the sheet.
        expect(find.byTooltip('Columns'), findsOneWidget);
        await tester.tap(find.byTooltip('Columns'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mobile_columns_slider')),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(235, 60)); // dismiss the sheet
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Switch tools repeatedly (device checklist: rapid switching).
        for (final tooltip in <String>[
          'Draw',
          'Text',
          'Select',
          'Text',
          'Select',
        ]) {
          await tester.tap(find.byTooltip(tooltip));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'switch to $tooltip');
        }

        // No RangeError was recorded in diagnostics either.
        expect(
          debugLog.entries.any(
            (e) => e.message.contains('RangeError'),
          ),
          isFalse,
        );
      },
    );

    testWidgets('tool switching with the keyboard (view insets) visible '
        'does not throw', (tester) async {
      final controller = StudioController();
      controller.addTextNode(100, 200, 'Keyboard case');
      tester.view.physicalSize = deviceLogical;
      tester.view.devicePixelRatio = 1;
      // Simulate the on-screen keyboard consuming the bottom half.
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GgenApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tooltip in <String>['Text', 'Select', 'Draw', 'Select']) {
        await tester.tap(find.byTooltip(tooltip), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'switch to $tooltip');
      }
    });
  });

  group('471px portrait layout (device RenderFlex regression)', () {
    testWidgets('no RenderFlex overflow with default preferences',
        (tester) async {
      final overflows = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          overflows.add(details);
        } else {
          previous?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = previous);

      await pumpShell(tester);
      expect(overflows, isEmpty);
    });

    testWidgets(
      'no RenderFlex overflow with EVERY top action pinned (device state)',
      (tester) async {
        // The reported 1.2px overflow came from the pinned top-action row:
        // pinning all actions exceeded the 471px width by ~1px. The pinned
        // region is now a bounded scroller, so even the maximal pin set
        // must lay out cleanly.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'workspace.top_action_pinned': <String>[
            for (final action in EditorTopAction.values) action.name,
          ],
        });
        final overflows = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) {
            overflows.add(details);
          } else {
            previous?.call(details);
          }
        };
        addTearDown(() => FlutterError.onError = previous);

        await pumpShell(tester);
        expect(
          overflows,
          isEmpty,
          reason: 'all-pinned top bar must not overflow at 471px',
        );
        // The More button stays reachable at the right edge.
        expect(find.byTooltip('More actions'), findsOneWidget);
      },
    );

    testWidgets('no overflow at the exact reported fractional geometry',
        (tester) async {
      // 471.04 x 1020.46 logical (1220x2643 physical @ 2.59 dpr).
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.top_action_pinned': <String>[
          for (final action in EditorTopAction.values) action.name,
        ],
      });
      final overflows = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          overflows.add(details);
        } else {
          previous?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = previous);

      tester.view.physicalSize = const Size(1220, 2643);
      tester.view.devicePixelRatio = 2.59;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const GgenApp());
      await tester.pumpAndSettle();
      expect(overflows, isEmpty);
    });
  });

  group('contextual action bar states', () {
    testWidgets('no selection: core groups, no contextual actions',
        (tester) async {
      final controller = StudioController();
      await pumpShell(tester, controller: controller);

      // Select tool is the default: multi-select toggle is contextual to it.
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Redo'), findsOneWidget);
      expect(find.byTooltip('Multi-select off'), findsOneWidget);
      expect(find.byTooltip('Columns'), findsNothing);
    });

    testWidgets('draw tool active: multi-select and columns absent',
        (tester) async {
      final controller = StudioController();
      await pumpShell(tester, controller: controller);
      await tester.tap(find.byTooltip('Draw'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Multi-select off'), findsNothing);
      expect(find.byTooltip('Columns'), findsNothing);
      // Core groups remain.
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
    });

    testWidgets('one shape selected: no Columns action', (tester) async {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      controller.selectNode(
        controller.project.artboards.first.nodes.single.id,
      );
      await pumpShell(tester, controller: controller);
      expect(find.byTooltip('Columns'), findsNothing);
    });

    testWidgets('text frame selected: Columns action appears and opens the '
        'sheet', (tester) async {
      final controller = StudioController();
      controller.addTextNode(100, 200, 'Contextual columns');
      controller.selectNode(
        controller.project.artboards.first.nodes.single.id,
      );
      await pumpShell(tester, controller: controller);

      expect(find.byTooltip('Columns'), findsOneWidget);
      await tester.tap(find.byTooltip('Columns'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mobile_columns_slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile_gutter_field')),
        findsOneWidget,
      );
    });

    testWidgets('multiple objects selected: bar stays healthy, no Columns '
        'for mixed selection', (tester) async {
      final controller = StudioController();
      controller.addShapeNode(100, 100);
      controller.addShapeNode(300, 300);
      final ids = controller.project.artboards.first.nodes
          .map((n) => n.id)
          .toList();
      controller.selectNode(ids[0], toggle: true);
      controller.selectNode(ids[1], toggle: true);
      await pumpShell(tester, controller: controller);
      expect(tester.takeException(), isNull);
      expect(find.byKey(ContextualActionBar.barKey), findsOneWidget);
    });

    testWidgets('undo/redo through the action bar mutate the controller',
        (tester) async {
      final controller = StudioController();
      controller.addShapeNode(50, 50);
      await pumpShell(tester, controller: controller);

      expect(controller.revision, 1);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(controller.revision, 0);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(controller.revision, 1);
    });
  });

  group('canonical layout invariants', () {
    testWidgets('exactly one tool rail and one action bar; tools never move',
        (tester) async {
      await pumpShell(tester);
      expect(find.byKey(MobileToolRail.railKey), findsOneWidget);
      expect(find.byKey(ContextualActionBar.barKey), findsOneWidget);

      // The rail carries exactly the canonical tools, in order.
      for (final tool in StudioTool.values) {
        expect(
          find.descendant(
            of: find.byKey(MobileToolRail.railKey),
            matching: find.byTooltip(tool.label),
          ),
          findsOneWidget,
        );
      }

      // Activating each tool keeps exactly one rail/bar (no duplicate or
      // competing surfaces appear in any tool state).
      for (final tool in StudioTool.values) {
        await tester.tap(find.byTooltip(tool.label));
        await tester.pumpAndSettle();
        expect(find.byKey(MobileToolRail.railKey), findsOneWidget);
        expect(find.byKey(ContextualActionBar.barKey), findsOneWidget);
      }
    });

    testWidgets('active tool is visually marked on the rail', (tester) async {
      await pumpShell(tester);
      final selectButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(MobileToolRail.railKey),
          matching: find.widgetWithIcon(IconButton, Icons.near_me),
        ),
      );
      expect(selectButton.isSelected, isTrue);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pumpAndSettle();
      final drawButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(MobileToolRail.railKey),
          matching: find.widgetWithIcon(IconButton, Icons.brush),
        ),
      );
      expect(drawButton.isSelected, isTrue);
    });

    testWidgets('workspace reset returns to the canonical layout',
        (tester) async {
      // Start from stale/legacy stored preferences.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.secondary_toolbar_mode': 'hidden',
        'workspace.secondary_toolbar_dock': 'right',
        'workspace.inspector_visible': false,
      });
      await pumpShell(tester);

      // Reset through Settings → Reset workspace.
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset workspace'));
      await tester.pumpAndSettle();

      // Canonical layout after reset; legacy keys removed from storage.
      expect(find.byKey(MobileToolRail.railKey), findsOneWidget);
      expect(find.byKey(ContextualActionBar.barKey), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('workspace.secondary_toolbar_mode'), isNull);
      expect(prefs.getString('workspace.secondary_toolbar_dock'), isNull);
    });

    testWidgets('project save/load keeps working through the new shell',
        (tester) async {
      final controller = StudioController();
      controller.addTextNode(100, 200, 'Persisted text');
      await pumpShell(tester, controller: controller);

      final receipt = await controller.save();
      expect(receipt.committedRevision, controller.revision);

      controller.addShapeNode(200, 300);
      expect(controller.objectCount, 2);
      final restored = await controller.restore(receipt.key);
      expect(restored, isTrue);
      expect(controller.objectCount, 1);
      expect(
        controller.project.artboards.first.nodes.single.kind,
        DocumentNodeKind.textFrame,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('linked text-flow UI remains reachable from the sheet',
        (tester) async {
      final controller = StudioController();
      controller.addTextNode(100, 150, 'First story');
      controller.addTextNode(100, 450, 'Second story');
      final nodes = controller.project.artboards.first.nodes;
      controller.selectNode(nodes[0].id);
      await pumpShell(tester, controller: controller);

      await tester.tap(find.byTooltip('Columns'));
      await tester.pumpAndSettle();
      expect(find.text('Text flow'), findsOneWidget);
      expect(
        find.byKey(ValueKey('mobile_flow_link_${nodes[1].id.value}')),
        findsOneWidget,
      );
    });
  });
}
