import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/main.dart';

void main() {
  testWidgets('renders the original studio shell', (tester) async {
    await tester.pumpWidget(const GgenApp());
    expect(find.text('GGEN'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Manual mode'), findsOneWidget);
  });
}
