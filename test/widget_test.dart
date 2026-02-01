import 'package:flutter_test/flutter_test.dart';

import 'package:vcr/app.dart';

void main() {
  testWidgets('VcrApp renders Connection Screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VcrApp());
    await tester.pumpAndSettle();

    // The connection screen should show the VCR title
    expect(find.text('Vibe Code Runner'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
  });
}
