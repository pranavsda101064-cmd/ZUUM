import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zuum_partner/main.dart' as app;

/// On-device visual smoke: sign in, then visit each bottom-nav branch.
/// Run against the live API with:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/device_smoke_test.dart -d <device-id> \
///     --dart-define=ENV=prod \
///     --dart-define=SMOKE_EMAIL=partner@zuum.in \
///     --dart-define=SMOKE_PASSWORD=123456
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment(
    'SMOKE_EMAIL',
    defaultValue: 'partner@zuum.in',
  );
  const password = String.fromEnvironment(
    'SMOKE_PASSWORD',
    defaultValue: '123456',
  );

  void mark(String name) => print('SMOKE_SCREEN:$name');

  Future<void> hold(WidgetTester tester, String name) async {
    mark(name);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('sign in and every partner tab', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await settle(tester);
    }

    expect(find.text('Partner sign in'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.tap(find.text('Sign in'));
    await settle(tester);
    await hold(tester, 'home');

    for (final tab in ['Earnings', 'Vehicles', 'Account']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
      await hold(tester, tab.toLowerCase());
    }
  });
}
