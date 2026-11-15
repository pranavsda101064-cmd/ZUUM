import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuum_customer/main.dart' as app;
import 'package:zuum_design_system/design_system.dart';

/// On-device smoke test: real plugins, real MapLibre view, real mock API.
/// Run with:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/device_smoke_test.dart -d <device-id>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Screen markers let the host capture real device screenshots (screencap),
  // because Flutter's takeScreenshot cannot include native map surfaces.
  void mark(String name) => print('SMOKE_SCREEN:$name');

  Future<void> hold(WidgetTester tester, String name) async {
    mark(name);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('register, home map, routed fares and tracking', (tester) async {
    SharedPreferences.setMockInitialValues({'zuum.onboarded': true});
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Login → register with a fresh mock account.
    expect(find.text('Create account'), findsWidgets);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    final email = 'smoke${DateTime.now().millisecondsSinceEpoch}@zuum.in';
    await tester.enterText(
      find.widgetWithText(ZTextField, 'First name'),
      'Smoke',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Last name'),
      'Tester',
    );
    await tester.enterText(find.widgetWithText(ZTextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Password'),
      'secret12',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('Create account').last);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Home: map + CTA.
    expect(find.text('Where to?'), findsOneWidget, reason: 'home should load');

    await hold(tester, 'home');

    // Plan a ride: Koramangala → Whitefield.
    await tester.tap(find.text('Where to?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'koramangala');
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.textContaining('Koramangala'), findsWidgets);
    await tester.tap(find.textContaining('Koramangala').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'whitefield');
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.textContaining('Whitefield'), findsWidgets);
    await tester.tap(find.textContaining('Whitefield').last);
    await tester.pumpAndSettle();

    // Fare screen: routed geometry should be on the map.
    expect(find.text('Choose a ride'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Auto'), findsWidgets);
    await hold(tester, 'fares');

    // Select Auto and book, then let the mock dispatch assign a captain.
    await tester.tap(find.text('Auto').first);
    await tester.pump();
    await tester.tap(find.textContaining('Book Auto'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await hold(tester, 'tracking');
  });
}
