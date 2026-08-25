import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
import 'package:ggen_app/workspace_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// More-menu action rows: reorder affordances must NOT consume permanent
/// visual space. Normal state = plain action rows; press-and-hold enters
/// reorder mode for that row (drag handle + up/down arrows appear); a drag
/// or arrow press commits the new order; release/outside interaction
/// returns the menu to its normal appearance; tapping a row still executes
/// the action; the persisted order survives reopen.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugLog.clear();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(471, 1020);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    await tester.pumpAndSettle();
  }

  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
  }

  testWidgets('normal menu shows actions with NO reorder affordances', (
    tester,
  ) async {
    await pumpShell(tester);
    await openMore(tester);

    // All default actions present as plain rows.
    for (final action in EditorTopAction.values) {
      expect(find.text(action.label), findsOneWidget);
    }
    // No reorder arrows and no drag handles anywhere in the menu.
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row executes the action', (tester) async {
    await pumpShell(tester);
    await openMore(tester);

    await tester.tap(find.text('Diagnostics export'));
    await tester.pumpAndSettle();

    // The diagnostics dialog is the executed action's visible result.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Diagnostics export'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press enters reorder mode; move-up commits the order', (
    tester,
  ) async {
    await pumpShell(tester);
    await openMore(tester);

    // Normal state: the second row ('New project') has no trailing controls.
    expect(find.byIcon(Icons.drag_indicator), findsNothing);

    // Press-and-hold the second row.
    await tester.longPress(find.text('New project'));
    await tester.pumpAndSettle();

    // Reorder affordances appeared for that row.
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

    // Move it up: the order changes and persists.
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    final prefs = await WorkspacePreferences.load();
    expect(prefs.topActionOrder.first, 'newProject');
    expect(prefs.topActionOrder[1], 'openProject');

    // Reorder mode stays active until an outside interaction.
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag handle reorders, release exits reorder mode, and the '
      'order survives reopen', (tester) async {
    await pumpShell(tester);
    await openMore(tester);

    // The persisted order only exists after a save; the built-in default
    // order is the enum order (Save project at index 2).
    final before = <String>[
      for (final action in EditorTopAction.values) action.name,
    ];
    expect(before.indexOf('save'), 2);

    await tester.longPress(find.text('Save project'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);

    // Drag the handle down past at least one row.
    await tester.drag(find.byIcon(Icons.drag_indicator), const Offset(0, 120));
    await tester.pumpAndSettle();

    // The order changed (Save project left index 2) and persisted.
    final after = (await WorkspacePreferences.load()).topActionOrder;
    expect(after.indexOf('save'), isNot(2));
    expect(after.toSet(), before.toSet());

    // Releasing the drag exited reorder mode: no affordances remain.
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);

    // Close and reopen: the persisted order is what renders.
    await tester.tapAt(const Offset(20, 20)); // dismiss the sheet
    await tester.pumpAndSettle();
    await openMore(tester);
    final tiles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .where(
          (t) =>
              t.title is Text &&
              (t.title as Text).data != 'Customize fullscreen controls',
        )
        .map((t) => (t.title as Text).data)
        .toList();
    expect(tiles, [
      'Open project',
      'New project',
      ...after.sublist(2).map(
        (name) => EditorTopAction.values.byName(name).label,
      ),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside reorder mode exits it without executing', (
    tester,
  ) async {
    await pumpShell(tester);
    await openMore(tester);

    await tester.longPress(find.text('New project'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);

    // Tap a DIFFERENT row: reorder mode exits, the action does NOT run.
    await tester.tap(find.text('Save project'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    // The More sheet is still open (a tap did not execute + close it) and
    // no save snackbar appeared.
    expect(find.text('More actions'), findsOneWidget);
    expect(find.textContaining('Saved r'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the reorder-mode row itself only exits reorder mode', (
    tester,
  ) async {
    await pumpShell(tester);
    await openMore(tester);

    await tester.longPress(find.text('Diagnostics export'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);

    await tester.tap(find.text('Diagnostics export'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    // The action was NOT executed (no dialog, sheet still open).
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('More actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
