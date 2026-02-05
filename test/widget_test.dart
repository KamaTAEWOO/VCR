import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vcr/app.dart';
import 'package:vcr/services/server_storage_service.dart';

void main() {
  testWidgets('VcrApp renders Connection Screen', (WidgetTester tester) async {
    // Set up mock shared preferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = ServerStorageService(prefs);

    await tester.pumpWidget(VcrApp(
      storageService: storageService,
      initialSavedServers: const [],
    ));
    // Use pump with duration instead of pumpAndSettle due to ongoing animations
    // from discovery service's CircularProgressIndicator
    await tester.pump(const Duration(milliseconds: 500));

    // The connection screen should show the VCR title
    expect(find.text('Vibe Code Runner'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
  });
}
