import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';
import 'package:zuum_partner/app/app.dart';

Widget buildPartnerApp({
  MockPartnerApi? api,
  TokenStorage? storage,
  bool welcomeSeen = true,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider
          .overrideWithValue(storage ?? InMemoryTokenStorage()),
      prefsStoreProvider
          .overrideWithValue(InMemoryPrefsStore(onboarded: welcomeSeen)),
      if (api != null) partnerApiProvider.overrideWithValue(api),
    ],
    child: const PartnerApp(),
  );
}

Future<void> pumpThroughSplash(
  WidgetTester tester,
  MockPartnerApi api, {
  TokenStorage? storage,
}) async {
  await tester.pumpWidget(buildPartnerApp(api: api, storage: storage));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1300)); // brand hold
  await tester.pumpAndSettle();
}

/// Pumps the app into the home tab. The home screen owns a live dot and a
/// simulated-GPS ticker, so `pumpAndSettle` never settles here.
Future<void> pumpSeededHome(
  WidgetTester tester,
  MockPartnerApi api,
  TokenStorage storage,
) async {
  // Tall viewport keeps every home section on screen — the map preview
  // swallows drag gestures, so scrolling it in tests is unreliable.
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(buildPartnerApp(api: api, storage: storage));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1300)); // brand hold
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Seeds an approved partner through the API (no wizard UI) and returns a
/// storage pre-loaded with the session.
Future<InMemoryTokenStorage> seedApprovedPartner(
  MockPartnerApi api, {
  String categoryCode = 'auto',
}) async {
  final session = await api.register(
    email: 'captain@zuum.in',
    password: 'secret12',
    firstName: 'Ravi',
    lastName: 'Kumar',
    phone: '9845012345',
  );
  for (final type in [
    KycDocType.licence,
    KycDocType.rc,
    KycDocType.insurance,
  ]) {
    await api.uploadDocument(type: type, filePath: 'demo://${type.name}.jpg');
  }
  await api.createVehicle(
    categoryCode: categoryCode,
    registrationNumber: 'KA 05 AB 1234',
    make: 'Bajaj',
    model: 'RE Auto',
    color: 'Yellow',
  );
  await api.submitKyc();
  final storage = InMemoryTokenStorage();
  await storage.saveSession(session);
  return storage;
}

/// Goes online and accepts a fabricated offer straight through the API.
Future<PartnerTrip> seedAssignedTrip(MockPartnerApi api) async {
  await api.setOnline(online: true);
  final offer = api.createSimulatedOffer();
  return api.acceptOffer(offer.id);
}

Future<void> pumpTripScreen(WidgetTester tester) async {
  await tester.tap(find.text('Open trip'));
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> settleAction(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> registerViaUi(WidgetTester tester) async {
  await tester.tap(find.text('Create account'));
  await tester.pumpAndSettle();
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
    'captain@zuum.in',
  );
  await tester.enterText(
    find.widgetWithText(ZTextField, 'Mobile number'),
    '9845012345',
  );
  await tester.enterText(
    find.widgetWithText(ZTextField, 'Password'),
    'secret12',
  );
  await tester.tap(find.text('Create partner account'));
  await tester.pumpAndSettle();
  expect(find.text('Personal details'), findsOneWidget);
}

Future<void> completeWizard(WidgetTester tester) async {
  // Step 1 — details are prefilled from registration.
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  // Step 2 — licence.
  await tester.enterText(
    find.widgetWithText(ZTextField, 'Licence number'),
    'KA0120180012345',
  );
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  // Step 3 — vehicle.
  await tester.tap(find.text('Auto'));
  await tester.pump();
  await tester.enterText(
    find.widgetWithText(ZTextField, 'Registration number'),
    'KA 05 AB 1234',
  );
  await tester.enterText(find.widgetWithText(ZTextField, 'Make'), 'Bajaj');
  await tester.enterText(find.widgetWithText(ZTextField, 'Model'), 'RE Auto');
  await tester.enterText(find.widgetWithText(ZTextField, 'Colour'), 'Yellow');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  // Step 4 — documents via the demo option (deterministic, no plugins).
  for (final doc in ['Driving licence', 'Vehicle RC', 'Insurance']) {
    await tester.tap(find.text(doc));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use demo document (dev)'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  // Step 5 — payout account.
  await tester.enterText(
    find.widgetWithText(ZTextField, 'Account holder name'),
    'Ravi Kumar',
  );
  await tester.enterText(
    find.widgetWithText(ZTextField, 'Account number'),
    '123456789012',
  );
  await tester.enterText(
    find.widgetWithText(ZTextField, 'IFSC code'),
    'HDFC0001234',
  );
  await tester.tap(find.text('Submit for review'));
  await tester.pumpAndSettle();
}

Future<void> goOnline(WidgetTester tester) async {
  await tester.tap(find.byType(Switch));
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  expect(find.text('ONLINE'), findsOneWidget);
}

Future<void> openSimulatedOffer(WidgetTester tester) async {
  if (find.text('OFFLINE').evaluate().isNotEmpty) {
    await tester.tap(find.byType(Switch));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('ONLINE'), findsOneWidget);
  }
  await tester.tap(find.text('Simulate offer (dev)'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text('NEW TRIP REQUEST'), findsOneWidget);
}

/// Unmounts the tree so provider-held timers (offer simulator, GPS ticker)
/// are cancelled before the framework's pending-timer invariant runs.
Future<void> tearDownHome(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('wrong credentials show the server error banner', (tester) async {
    final api = MockPartnerApi(latency: Duration.zero);
    await pumpThroughSplash(tester, api);

    expect(find.text('Partner sign in'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Email'),
      'ghost@zuum.in',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Password'),
      'secret12',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password'), findsOneWidget);
    expect(find.text('Partner sign in'), findsWidgets); // stayed on login
  });

  testWidgets('register → wizard blocked until documents are uploaded',
      (tester) async {
    final api = MockPartnerApi(latency: Duration.zero);
    await pumpThroughSplash(tester, api);
    await registerViaUi(tester);

    await tester.tap(find.text('Continue')); // details
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Licence number'),
      'KA0120180012345',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Registration number'),
      'KA 05 AB 1234',
    );
    await tester.enterText(find.widgetWithText(ZTextField, 'Make'), 'Bajaj');
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Model'),
      'RE Auto',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Colour'),
      'Yellow',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // On the documents step: continuing without uploads must block.
    expect(find.text('Documents'), findsWidgets);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Upload all three documents to continue'), findsOneWidget);
  });

  testWidgets('submitted KYC lands on the pending verification screen',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: const Duration(hours: 1),
    );
    await pumpThroughSplash(tester, api);
    await registerViaUi(tester);
    await completeWizard(tester);

    expect(find.text('Verification in progress'), findsOneWidget);
    expect(find.text('ಪರಿಶೀಲನೆ ನಡೆಯುತ್ತಿದೆ'), findsOneWidget);
    expect(find.text('Documents submitted'), findsOneWidget);
    expect(find.text('SUBMITTED'), findsOneWidget);
  });

  testWidgets('approved partner lands on the offline home dashboard',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    await pumpSeededHome(tester, api, storage);

    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Go online to receive trips'), findsOneWidget);
    for (final tab in ['Home', 'Earnings', 'Vehicles', 'Account']) {
      expect(find.text(tab), findsWidgets);
    }
    expect(find.text('NET TODAY'), findsOneWidget);
    expect(find.text('ACCEPTANCE'), findsOneWidget);
    await tearDownHome(tester);
  });

  testWidgets('going online flips the hero status', (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    await pumpSeededHome(tester, api, storage);

    expect(find.text('OFFLINE'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('You are visible to riders nearby'), findsOneWidget);
    expect(api.onlineNow, isTrue);
    await tearDownHome(tester);
  });

  testWidgets('accepting a simulated offer creates an active trip',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    await pumpSeededHome(tester, api, storage);

    await openSimulatedOffer(tester);
    expect(find.text('Accept trip'), findsOneWidget);
    await tester.tap(find.text('Accept trip'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text('Accept trip'), findsNothing);
    expect(find.text('Open trip'), findsOneWidget);
    expect(await api.activeTrip(), isNotNull);
    await tearDownHome(tester);
  });

  testWidgets('declining a simulated offer leaves no active trip',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    await pumpSeededHome(tester, api, storage);

    await openSimulatedOffer(tester);
    await tester.tap(find.text('Decline'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text('NEW TRIP REQUEST'), findsNothing);
    expect(find.text('Open trip'), findsNothing);
    expect(await api.activeTrip(), isNull);
    await tearDownHome(tester);
  });

  testWidgets('ride trip: arrive → OTP start → complete', (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    final trip = await seedAssignedTrip(api);
    await pumpSeededHome(tester, api, storage);

    await pumpTripScreen(tester);
    expect(find.text('Arrived at pickup'), findsOneWidget);

    await tester.tap(find.text('Arrived at pickup'));
    await settleAction(tester);
    expect(find.text('Trip OTP'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(ZTextField, 'Trip OTP'),
      '0000',
    );
    await tester.tap(find.text('Start trip'));
    await settleAction(tester);
    expect(find.text('Incorrect OTP'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(ZTextField, 'Trip OTP'),
      trip.devOtpHint!,
    );
    await tester.tap(find.text('Start trip'));
    await settleAction(tester);
    expect(find.text('Complete trip'), findsOneWidget);

    await tester.tap(find.text('Complete trip'));
    await settleAction(tester);
    expect(find.text('Trip completed'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
    expect(await api.activeTrip(), isNull);

    await tester.tap(find.text('Back to home'));
    await settleAction(tester);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('Open trip'), findsNothing);
    await tearDownHome(tester);
  });

  testWidgets('goods trip requires the delivery OTP before completion',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api, categoryCode: 'goods_3w');
    final trip = await seedAssignedTrip(api);
    expect(trip.kind, OfferKind.goods);

    await pumpSeededHome(tester, api, storage);
    await pumpTripScreen(tester);
    await tester.tap(find.text('Arrived at pickup'));
    await settleAction(tester);
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Trip OTP'),
      trip.devOtpHint!,
    );
    await tester.tap(find.text('Start trip'));
    await settleAction(tester);

    // Server refuses to close a POD trip before the delivery OTP.
    await expectLater(
      api.complete(trip.bookingId),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'pod_missing'),
      ),
    );
    expect(find.text('Delivery OTP'), findsOneWidget);
    expect(find.text('Complete delivery'), findsNothing);

    await tester.enterText(
      find.widgetWithText(ZTextField, 'Delivery OTP'),
      '0000',
    );
    await tester.tap(find.text('Verify delivery OTP'));
    await settleAction(tester);
    expect(find.text('Incorrect delivery OTP'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(ZTextField, 'Delivery OTP'),
      trip.devOtpHint!,
    );
    await tester.tap(find.text('Verify delivery OTP'));
    await settleAction(tester);
    expect(find.text('Complete delivery'), findsOneWidget);

    await tester.tap(find.text('Complete delivery'));
    await settleAction(tester);
    expect(find.text('Trip completed'), findsOneWidget);
    await tearDownHome(tester);
  });

  testWidgets('earnings tab shows the commission split and range totals',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    await pumpSeededHome(tester, api, storage);

    await tester.tap(find.text('Earnings'));
    await settleAction(tester);
    expect(find.text('NET EARNINGS'), findsOneWidget);
    expect(find.text('Recent trips'), findsOneWidget);
    expect(find.text('Auto'), findsWidgets);

    await tester.tap(find.text('This month'));
    await settleAction(tester);
    expect(find.text('Tata Ace'), findsWidgets);
    await tearDownHome(tester);
  });

  testWidgets('vehicles tab toggles availability and adds a vehicle',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    await pumpSeededHome(tester, api, storage);

    await tester.tap(find.text('Vehicles'));
    await settleAction(tester);
    expect(find.text('KA05AB1234'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settleAction(tester);
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('Add vehicle'));
    await settleAction(tester);
    await tester.tap(find.text('SUV'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Registration number'),
      'KA 09 XY 9999',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Make'),
      'Toyota',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Model'),
      'Innova',
    );
    await tester.enterText(
      find.widgetWithText(ZTextField, 'Colour'),
      'White',
    );
    await tester.tap(find.text('Save vehicle'));
    await settleAction(tester);

    expect(find.text('KA09XY9999'), findsOneWidget);
    await tearDownHome(tester);
  });

  testWidgets('fleet console lists drivers and assigns a vehicle',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    await pumpSeededHome(tester, api, storage);

    await tester.tap(find.text('Vehicles'));
    await settleAction(tester);
    await tester.tap(find.text('Open fleet console'));
    await settleAction(tester);

    expect(find.text('Fleet console'), findsWidgets);
    expect(find.text('Suresh Babu'), findsOneWidget);
    expect(find.text('Manjunath H'), findsOneWidget);
    expect(find.text('Lakshmi R'), findsOneWidget);
    expect(find.text('DRIVERS ONLINE'), findsOneWidget);

    // Lakshmi has no vehicle — assign the garage's Active.
    await tester.tap(find.byIcon(Icons.link_rounded).last);
    await settleAction(tester);
    expect(find.textContaining('Assign a vehicle to Lakshmi R'), findsOneWidget);
    await tester.tap(find.textContaining('Bajaj RE Auto'));
    await settleAction(tester);

    expect(find.text('Vehicle assigned to Lakshmi R.'), findsOneWidget);
    expect(find.text('KA05AB1234'), findsWidgets);
    await tearDownHome(tester);
  });

  testWidgets('new partners see the welcome tour before login',
      (tester) async {
    final api = MockPartnerApi(latency: Duration.zero);
    await tester.pumpWidget(buildPartnerApp(api: api, welcomeSeen: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text('Your day, your earnings.'), findsOneWidget);
    expect(find.text('PARTNER'), findsWidgets);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Partner sign in'), findsWidgets);
  });

  testWidgets('demo sign-in lands on the dashboard in mock builds',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    await pumpThroughSplash(tester, api);

    await tester.tap(find.text('Demo partner (dev)'));
    await settleAction(tester);
    await settleAction(tester);

    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Demo Partner'), findsWidgets);
    await tearDownHome(tester);
  });

  testWidgets('account tab shows profile, documents and signs out',
      (tester) async {
    final api = MockPartnerApi(
      latency: Duration.zero,
      kycReviewDelay: Duration.zero,
    );
    final storage = await seedApprovedPartner(api);
    await pumpSeededHome(tester, api, storage);

    await tester.tap(find.text('Account'));
    await settleAction(tester);
    expect(find.text('Ravi Kumar'), findsWidgets);
    expect(find.text('VERIFIED'), findsWidgets);
    expect(find.text('Driving licence'), findsOneWidget);
    expect(find.text('Vehicle RC'), findsOneWidget);
    expect(find.text('RATING'), findsOneWidget);
    expect(find.text('MOCK'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await settleAction(tester);
    expect(find.text('Sign out of Zuum Partner?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await settleAction(tester);
    expect(find.text('Partner sign in'), findsWidgets);
    await tearDownHome(tester);
  });
}
