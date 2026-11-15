import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuum_customer/main.dart' as app;

/// Live-API smoke for the production customer app.
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/prod_smoke_test.dart -d <device-id> \
///     --dart-define=ENV=prod \
///     --dart-define=SMOKE_EMAIL=customer@zuum.in \
///     --dart-define=SMOKE_PASSWORD=123456
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment(
    'SMOKE_EMAIL',
    defaultValue: 'customer@zuum.in',
  );
  const password = String.fromEnvironment(
    'SMOKE_PASSWORD',
    defaultValue: '123456',
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('live login, home and tabs', (tester) async {
    SharedPreferences.setMockInitialValues({'zuum.onboarded': true});
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.tap(find.text('Log in'));
    await settle(tester);
    await settle(tester);

    expect(find.text('Where to?'), findsOneWidget);
    for (final tab in ['Activity', 'Wallet', 'Account']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
    }
  });
}
