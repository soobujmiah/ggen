import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';

void main() {
  testWidgets('uses compact navigation without a side rail', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses the rail and inspector when space allows', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GgenApp());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
  });

  testWidgets('renders the original studio shell', (tester) async {
    await tester.pumpWidget(const GgenApp());
    expect(find.text('GGEN'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Manual mode'), findsOneWidget);
  });
}
