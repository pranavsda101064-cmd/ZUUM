import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_design_system/design_system.dart';

Widget host(Widget child) => MaterialApp(
      theme: ZuumTheme.light(),
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  group('ZOnlineHero', () {
    testWidgets('offline state + toggle callback', (tester) async {
      var value = false;
      await tester.pumpWidget(
        host(
          ZOnlineHero(
            online: false,
            onChanged: (v) => value = v,
            subtitle: '30+ trips today in your area',
          ),
        ),
      );
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('Go online to receive trips'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      expect(value, isTrue);
    });

    testWidgets('online state shows lime status and earnings', (tester) async {
      await tester.pumpWidget(
        host(
          const ZOnlineHero(
            online: true,
            onChanged: _noop,
            earningsLabel: '₹1,240 today',
          ),
        ),
      );
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Receiving trips in Bengaluru'), findsOneWidget);
      expect(find.text('₹1,240 today'), findsOneWidget);
    });
  });

  group('ZOfferCard', () {
    testWidgets('renders offer details and accepts', (tester) async {
      var accepted = false;
      var declined = false;
      await tester.pumpWidget(
        host(
          ZOfferCard(
            serviceCategoryName: 'Auto',
            isGoods: false,
            pickupAddress: 'Indiranagar · 100 Feet Rd',
            dropAddress: 'MG Road · Metro',
            distanceLabel: '4.8 km',
            pickupEtaLabel: '4 min',
            farePaise: 14200,
            earningPaise: 11360,
            secondsLeft: 12,
            totalSeconds: 15,
            surgeMultiplier: 1.2,
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      );

      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('RIDE'), findsOneWidget);
      expect(find.text('1.2x'), findsOneWidget);
      expect(find.text('4.8 km'), findsOneWidget);
      expect(find.text('₹142'), findsOneWidget);
      expect(find.text('You earn ₹113.60'), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // countdown ring

      await tester.tap(find.text('Accept trip'));
      await tester.tap(find.text('Decline'));
      expect(accepted, isTrue);
      expect(declined, isTrue);
    });

    testWidgets('expired offer disables accept', (tester) async {
      var accepted = false;
      await tester.pumpWidget(
        host(
          ZOfferCard(
            serviceCategoryName: 'Tata Ace',
            isGoods: true,
            pickupAddress: 'A',
            dropAddress: 'B',
            distanceLabel: '6.1 km',
            pickupEtaLabel: '7 min',
            farePaise: 48000,
            earningPaise: 38400,
            secondsLeft: 0,
            totalSeconds: 15,
            goodsSummary: 'Furniture · 120 kg',
            onAccept: () => accepted = true,
          ),
        ),
      );
      expect(find.text('GOODS'), findsOneWidget);
      expect(find.text('Furniture · 120 kg'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      await tester.tap(find.text('Expired'));
      expect(accepted, isFalse);
    });
  });

  group('ZStatCard', () {
    testWidgets('renders label, value and caption', (tester) async {
      await tester.pumpWidget(
        host(
          const ZStatCard(
            label: 'Net earnings',
            value: '₹1,240',
            caption: 'Today · 7 trips',
            icon: Icons.account_balance_wallet_outlined,
            accent: true,
          ),
        ),
      );
      expect(find.text('NET EARNINGS'), findsOneWidget);
      expect(find.text('₹1,240'), findsOneWidget);
      expect(find.text('Today · 7 trips'), findsOneWidget);
    });
  });

  group('ZCommissionBreakdown', () {
    testWidgets('shows fare, commission and take-home', (tester) async {
      await tester.pumpWidget(
        host(
          const ZCommissionBreakdown(
            farePaise: 14200,
            commissionPaise: 2840,
            earningPaise: 11360,
          ),
        ),
      );
      expect(find.text('Trip fare'), findsOneWidget);
      expect(find.text('Platform commission (20%)'), findsOneWidget);
      expect(find.text('- ₹28.40'), findsOneWidget);
      expect(find.text('You earn'), findsOneWidget);
      expect(find.text('₹113.60'), findsOneWidget);
    });
  });

  group('ZDocumentTile', () {
    testWidgets('verified and expired states', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              ZDocumentTile(
                label: 'Driving licence',
                status: ZDocStatus.verified,
                fileName: 'licence.jpg',
                onTap: () => tapped++,
              ),
              ZDocumentTile(
                label: 'Insurance',
                status: ZDocStatus.expired,
                expiresAt: DateTime(2026, 1, 12),
                onTap: () => tapped++,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.textContaining('Valid till 12 Jan 2026'), findsOneWidget);

      await tester.tap(find.text('Driving licence'));
      expect(tapped, 1);
    });
  });

  group('ZLiveDot', () {
    testWidgets('builds and animates', (tester) async {
      await tester.pumpWidget(host(const ZLiveDot()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ZLiveDot), findsOneWidget);
    });
  });
}

void _noop(bool _) {}
