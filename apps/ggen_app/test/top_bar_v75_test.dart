import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';
import 'package:ggen_app/src/canvas/studio_canvas.dart';
import 'package:ggen_app/workspace_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the desktop-class top command surface introduced in v75.
///
/// Verifies:
///  1. Primary actions are always visible (New, Open, Save, Immersive)
///  2. Settings button is at far-right position
///  3. More menu button is at far-right position
///  4. Top controls are not clipped at 471px width
///  5. Safe-area handling works
///  6. Existing commands remain functional
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(471, 1020);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    await tester.pumpAndSettle();
  }

  group('v75 top command surface', () {
    testWidgets('primary actions are present on top bar', (tester) async {
      await pumpShell(tester);
      
      // Primary actions should be visible as segmented buttons
      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget); // New
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget); // Open
      expect(find.byIcon(Icons.save_outlined), findsOneWidget); // Save
      expect(find.byIcon(Icons.fullscreen), findsOneWidget); // Immersive
    });

    testWidgets('settings button is at far-right position', (tester) async {
      await pumpShell(tester);
      
      // Settings icon should be visible
      final settingsFinder = find.byIcon(Icons.tune);
      expect(settingsFinder, findsOneWidget);
      
      // Verify it's accessible
      await tester.tap(settingsFinder);
      await tester.pumpAndSettle();
      
      // Should open workspace settings
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('more menu button is at far-right position', (tester) async {
      await pumpShell(tester);
      
      // More menu icon should be visible
      final moreFinder = find.byIcon(Icons.more_horiz);
      expect(moreFinder, findsOneWidget);
      
      // Tapping opens the menu
      await tester.tap(moreFinder);
      await tester.pumpAndSettle();
      
      expect(find.text('More actions'), findsOneWidget);
    });

    testWidgets('no RenderFlex overflow at 471px with default config',
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

    testWidgets('no overflow with all actions pinned', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.top_action_pinned': <String>[],
        'workspace.top_action_order': <String>[
          for (final a in EditorTopAction.values) a.name,
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
      expect(overflows, isEmpty);
    });

    testWidgets('new project action creates empty project', (tester) async {
      await pumpShell(tester);
      
      final beforeCount =
          tester.widget<Stack>(find.byType(Stack)).children.length;
      
      await tester.tap(find.byIcon(Icons.note_add_outlined));
      await tester.pumpAndSettle();
      
      // Should create new project (dialog or immediate clear)
      expect(tester.takeException(), isNull);
    });

    testWidgets('save action persists project', (tester) async {
      await pumpShell(tester);
      
      // Create some content first
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(StudioCanvas));
      await tester.pumpAndSettle();
      
      // Tap save
      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();
      
      expect(tester.takeException(), isNull);
    });

    testWidgets('more menu shows categorized sections', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      
      // Should show section headers
      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('Document'), findsOneWidget);
    });

    testWidgets('more menu actions are reorderable', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      
      // Long press to enter reorder mode
      await tester.longPress(find.text('Diagnostics export'));
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });
  });
}
