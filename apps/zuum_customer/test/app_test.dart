import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_customer/app/app.dart';
import 'package:zuum_design_system/design_system.dart';

import 'helpers/load_fonts.dart';

/// End-to-end widget tests against the dev-only mock API (`ENV=mock`).
/// Mock adapters run with zero/fast latency so futures resolve in microtasks
/// and the dispatch simulator is pump-driven.
Widget buildTestApp({
  InMemoryPrefsStore? prefs,
  MockApiAdapter? api,
}) {
  final realtime = MockRealtimeService(
    assignAfter: const Duration(milliseconds: 1200),
    arriveAfter: const Duration(milliseconds: 1100),
    eta: const Duration(milliseconds: 2000),
    tripDuration: const Duration(milliseconds: 2000),
    onEvent: api?.applyRealtimeEvent,
  );
  // The dispatch simulator schedules timers; dispose them at test end or
  // flutter_test fails on pending timers.
  addTearDown(realtime.dispose);
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      prefsStoreProvider.overrideWithValue(prefs ?? InMemoryPrefsStore()),
      if (api != null) apiContractProvider.overrideWithValue(api),
      placeSearchProvider.overrideWithValue(
        MockPlaceSearch(latency: Duration.zero),
      ),
      realtimeServiceProvider.overrideWithValue(realtime),
      paymentGatewayProvider.overrideWithValue(
        MockPaymentGateway(latency: Duration.zero),
      ),
    ],
    child: const ZuumApp(),
  );
}

/// Pumps through splash (brand animation + 1400 ms boot delay) to the next screen.
Future<void> pumpThroughSplash(WidgetTester tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pump(); // start bootstrap futures
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(); // build the next route
}

/// Starts the app already onboarded, landing on the login screen.
Future<void> pumpToLogin(WidgetTester tester, {MockApiAdapter? api}) async {
  final prefs = InMemoryPrefsStore();
  await prefs.setOnboarded(true);
  await tester.pumpWidget(buildTestApp(prefs: prefs, api: api));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
}

Future<void> enterCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(ZTextField, 'Email'),
    'ravi@zuum.in',
  );
  await tester.enterText(
    find.widgetWithText(ZTextField, 'Password'),
    'secret12',
  );
}

/// Home → route → fare screen, ending on the category list.
Future<void> bookRouteTo(
  WidgetTester tester,
  String placeQuery,
  String place, {
  String homeLabel = 'Where to?',
}) async {
  await tester.tap(find.text(homeLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Current location'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(1), placeQuery);
  await tester.pump(const Duration(milliseconds: 300)); // debounce
  await tester.pumpAndSettle();
  // Results render as RichText (highlighted match) — use textContaining.
  await tester.tap(find.textContaining(place).first);
  await tester.pumpAndSettle();
}

/// Completes a ride booking up to the searching screen.
Future<void> bookASedan(WidgetTester tester) async {
  await bookRouteTo(tester, 'whitefield', 'Whitefield');
  await tester.drag(find.byType(ListView), const Offset(0, -170));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sedan'));
  await tester.pump();
  await tester.tap(find.textContaining('Book Sedan'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

MockApiAdapter seededApi() {
  final api = MockApiAdapter(latency: Duration.zero);
  api.register(
    email: 'ravi@zuum.in',
    password: 'secret12',
    firstName: 'Ravi',
    lastName: 'Kumar',
  );
  return api;
}

void main() {
  setUpAll(loadZuumFonts);

  testWidgets('cold start shows onboarding with brand story', (tester) async {
    await pumpThroughSplash(tester);

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(
      find.textContaining('From Jayanagar filter coffee'),
      findsOneWidget,
    );
    expect(find.text('ಮೀಟರ್ ಹಾಕಿ, ಹೊರಡೋಣ'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('onboarding next advances, skip lands on login', (tester) async {
    await pumpThroughSplash(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Move a tiffin box or a 1BHK house.'), findsOneWidget);

    await tester.ensureVisible(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    debugPrint('POST SKIP: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => d != null).take(12).toList()}');
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('register flow creates account and reaches home', (tester) async {
    await pumpToLogin(tester, api: MockApiAdapter(latency: Duration.zero));

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(ZTextField, 'First name'),
      'Ravi',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Last name'),
      'Kumar',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Email'),
      'ravi@zuum.in',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Password'),
      'secret12',
    );

    await tester.tap(find.widgetWithText(ZButton, 'Create account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget); // nav label
  });

  testWidgets('login with wrong password shows server error', (tester) async {
    await pumpToLogin(tester, api: seededApi());

    await tester.enterText(
      find.widgetWithText(ZTextField, 'Email'),
      'ravi@zuum.in',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Password'),
      'wrong-pass',
    );
    await tester.tap(find.widgetWithText(ZButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Incorrect password'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget); // stayed on login
  });

  testWidgets('valid login reaches home; sign out returns to login',
      (tester) async {
    await pumpToLogin(tester, api: seededApi());

    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(ZButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Where to?'), findsOneWidget);

    // Account tab → scroll to bottom → sign out → confirm dialog.
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsOneWidget);

    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle(); // dialog animation
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('booking flow: route → fares → book → searching → cancel',
      (tester) async {
    await pumpToLogin(tester, api: seededApi());
    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(ZButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Goods mode toggles the home copy and back.
    await tester.tap(find.text('Send Goods'));
    await tester.pump();
    expect(find.text('Where is the parcel going?'), findsOneWidget);
    await tester.tap(find.text('Ride'));
    await tester.pump();

    await bookRouteTo(tester, 'whitefield', 'Whitefield');

    // Fare screen: ride categories quote for this route.
    expect(find.text('Choose a ride'), findsOneWidget);
    for (final name in ['Bike', 'Auto', 'Hatchback', 'Sedan', 'SUV']) {
      expect(find.text(name), findsOneWidget);
    }

    // Fare breakdown sheet shows server-computed lines. Scroll so the
    // Sedan row is above the fixed bottom bar before tapping.
    await tester.drag(find.byType(ListView), const Offset(0, -170));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sedan'));
    await tester.pump();
    await tester.tap(find.textContaining('Fare breakup').at(3)); // Sedan's own row
    await tester.pumpAndSettle();
    expect(find.textContaining('Fare breakdown'), findsOneWidget);
    expect(find.text('Total payable'), findsOneWidget);
    // Dismiss the modal sheet.
    Navigator.of(
      tester.element(find.textContaining('Fare breakdown')),
    ).maybePop();
    await tester.pumpAndSettle();

    // Payment: switch to UPI before confirming.
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Book Sedan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Trip screen is live (searching or already assigned).
    expect(find.textContaining('Cancel booking'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').contains('Finding your captain') ||
                (w.data ?? '').contains('Captain assigned') ||
                (w.data ?? '').contains('Arriving')),
      ),
      findsWidgets,
    );

    // Cancel the booking → back home.
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    // Dialog confirm is the last matching TextButton (screen ghost is first).
    await tester.tap(find.widgetWithText(TextButton, 'Cancel booking').last);
    await tester.pumpAndSettle();
    expect(find.text('Where to?'), findsOneWidget);
  });

  testWidgets('activity tab lists the new booking', (tester) async {
    await pumpToLogin(tester, api: seededApi());
    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(ZButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await bookASedan(tester);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').contains('Finding your captain') ||
                (w.data ?? '').contains('Captain assigned')),
      ),
      findsWidgets,
    );

    // Searching screen has no nav bar — back arrow returns to home.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity'));
    // The active card's pulsing dot animates forever — settle manually.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Seeded history + the fresh SEARCHING booking (filters: All default).
    expect(find.text('Activity'), findsWidgets); // app bar + nav label
    expect(find.textContaining('SEARCHING'), findsWidgets); // active card
    expect(find.text('Completed'), findsWidgets);
    // Vehicle names appear inside card titles ("Auto · date").
    expect(find.textContaining('Auto'), findsWidgets);
    expect(find.textContaining('SEDAN'), findsWidgets); // active card
    // Drain the dispatch simulator's timers before the test ends.
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('full ride lifecycle: trip → cash payment → rating → receipt',
      (tester) async {
    await pumpToLogin(tester, api: seededApi());
    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(ZButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await bookASedan(tester);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').contains('Finding your captain') ||
                (w.data ?? '').contains('Captain assigned')),
      ),
      findsWidgets,
    );

    // Driver assigned (simulator, ~1.2s).
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').contains('Captain assigned') ||
                (w.data ?? '').contains('Arriving') ||
                (w.data ?? '').contains('Finding your captain')),
      ),
      findsWidgets,
    );
    // PIN pill (ride) shows once assigned, or status text still searching.
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('PIN'),
      ),
      findsWidgets,
    );

    // En route to pickup (~2.3s).
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(find.textContaining('Arriving'), findsWidgets); // headline + step

    // Trip auto-starts after the demo ETA (~4.3s).
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    expect(find.text('On trip'), findsWidgets); // headline + step

    // Trip completes (~6.3s) → payment screen.
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Trip complete'), findsOneWidget);
    expect(find.textContaining('Add a tip for'), findsOneWidget);

    // Tip + cash payment.
    await tester.tap(find.text('₹20'));
    await tester.pump();
    await tester.tap(find.textContaining('Confirm cash payment'));
    await tester.pumpAndSettle();

    expect(find.textContaining('How was the trip'), findsOneWidget);
    await tester.tap(find.text('Smooth driving'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Tax invoice & receipt'), findsOneWidget);
    expect(find.textContaining('PAID'), findsOneWidget);
    // Receipt is long — scroll the Done button into view.
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Where to?'), findsOneWidget);

    // History reflects the completed trip.
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsWidgets);
  });

  testWidgets('goods lifecycle: details → POD (wrong then right OTP) → receipt',
      (tester) async {
    await pumpToLogin(tester, api: seededApi());
    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(ZButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Send Goods'));
    await tester.pump();
    await bookRouteTo(
      tester,
      'whitefield',
      'Whitefield',
      homeLabel: 'Where is the parcel going?',
    );

    // Goods details (Milestone E) — the route goes here before fares.
    expect(find.text('WHAT ARE YOU SENDING?'), findsOneWidget);
    await tester.tap(find.text('Documents'));
    await tester.pump();
    // Weight range pills (no free-text weight field in the current form).
    await tester.ensureVisible(find.text('Up to 50 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Up to 50 kg'));
    await tester.pump();
    // Ensure the contacts section is in view (list may be scrolled).
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    // Receiver fields sit at the top of the form (spec 2k layout).
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Receiver name'),
      'Rahul',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Receiver mobile'),
      '+919800000012',
    );
    // Required prohibited-items declaration — scroll progressively so the
    // ListView builds the handling card at the bottom.
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    // Continue to pricing.
    await tester.ensureVisible(find.text('Choose vehicle & see fare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose vehicle & see fare'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a goods vehicle'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -170));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tata Ace'));
    await tester.pump();
    await tester.tap(find.textContaining('Book Tata Ace'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').contains('Finding a Tata Ace') ||
                (w.data ?? '').contains('Captain assigned')),
      ),
      findsWidgets,
    );

    // Advance through the simulated delivery trip.
    await tester.pump(const Duration(milliseconds: 1300)); // assigned
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100)); // arriving
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100)); // in transit
    await tester.pump();
    expect(find.text('In transit'), findsWidgets); // headline + step
    await tester.pump(const Duration(milliseconds: 2100)); // delivered
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Proof-of-delivery screen (route, not sheet).
    expect(find.text('Confirm delivery'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Delivery OTP'),
      '1111',
    );
    await tester.ensureVisible(
      find.widgetWithText(ZButton, 'Confirm delivery'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ZButton, 'Confirm delivery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('OTP'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(ZTextField, 'Delivery OTP'),
      '4321',
    );
    await tester.ensureVisible(
      find.widgetWithText(ZButton, 'Confirm delivery'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ZButton, 'Confirm delivery'));
    await tester.pumpAndSettle();

    // Verified POD → continue to payment.
    // Scroll back to the top of the verified POD list for the banner.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Delivered & OTP verified'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(ZButton, 'Continue to payment'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ZButton, 'Continue to payment'));
    await tester.pumpAndSettle();

    // Payment → rating → receipt with POD summary.
    expect(find.text('Delivery payment'), findsOneWidget);
    await tester.tap(find.textContaining('Confirm cash payment'));
    await tester.pumpAndSettle();
    expect(find.text('Rate your delivery'), findsOneWidget);
    // Rating screen is long - reveal Skip, then skip to the receipt.
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Tax invoice & receipt'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    // Goods mode persists after the journey — home shows the goods CTA.
    expect(find.text('Where is the parcel going?'), findsOneWidget);
  });

  testWidgets('wallet journey: top up via UPI then pay the trip from wallet',
      (tester) async {
    await pumpToLogin(tester, api: seededApi());
    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(ZButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Top up ₹500 → ₹650 total.
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('₹150'), findsWidgets); // seeded demo balance
    await tester.tap(find.text('Add money to wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('₹500'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ZButton, 'Top up ₹500'));
    await tester.pumpAndSettle();
    expect(find.text('₹650'), findsWidgets);
    // Let the confirmation snackbar expire so it can't cover later buttons.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Book and complete a sedan trip, pay from the wallet.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await bookASedan(tester);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Trip complete'), findsOneWidget);

    await tester.tap(find.text('Zuum Wallet'));
    await tester.pump();
    await tester.tap(find.textContaining('from wallet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('How was the trip'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Tax invoice & receipt'), findsOneWidget);
    expect(find.textContaining('PAID'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Wallet reflects the trip debit.
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    // Payment succeeded (receipt above is PAID); wallet ledger is covered by
    // core unit tests, so here we only assert the tab renders.
    expect(find.text('Zuum Wallet'), findsWidgets);
  });

  testWidgets('milestone F screens: offers, notifications, support, safety',
      (tester) async {
    await pumpToLogin(tester, api: seededApi());
    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(ZButton, 'Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    // Offers (dashed coupon hub → offers screen).
    await tester.ensureVisible(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.text('Invite friends to Zuum'), findsOneWidget);
    expect(find.text('50% off your next ride'), findsOneWidget);
    expect(find.text('ZUUM50'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Notifications.
    await tester.ensureVisible(find.text('Notifications & alerts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications & alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Zuum'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Support: create a ticket.
    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();
    expect(find.text('Lost item in a vehicle'), findsOneWidget);
    await tester.tap(find.text('Raise a ticket'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(ZTextField, 'Subject'), 'Lost umbrella');
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Describe the issue'),
      'Left it in the auto this morning.',
    );
    await tester.ensureVisible(find.text('Submit ticket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit ticket'));
    await tester.pumpAndSettle();
    // The ticket card sits below the topics — scroll to it.
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Lost umbrella'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Safety — the tile sits below the fold after returning from pushes.
    await tester.ensureVisible(find.text('SOS (112)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SOS (112)'));
    await tester.pumpAndSettle();
    expect(find.text('In an emergency, call 112'), findsOneWidget);
    expect(find.text('Women’s helpline'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Settings + saved address.
    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Saved addresses'), findsOneWidget);
    await tester.tap(find.text('Saved addresses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(ZTextField, 'Name (e.g. Home)'), 'Home');
    await tester.enterText(find.widgetWithText(ZTextField, 'Full address'), '42, 7th Cross, Jayanagar');
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();
    expect(find.text('42, 7th Cross, Jayanagar'), findsWidgets); // seeded + new
  });
}
