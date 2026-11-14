import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_design_system/design_system.dart';

void main() {
  group('ZSegmentedSwitch', () {
    testWidgets('renders segments and reports taps', (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: ZSegmentedSwitch(
                segments: const [
                  ZSegment(label: 'Ride', icon: Icons.local_taxi_outlined),
                  ZSegment(label: 'Send Goods', icon: Icons.inventory_2_outlined),
                ],
                selectedIndex: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Ride'), findsOneWidget);
      expect(find.text('Send Goods'), findsOneWidget);
      await tester.tap(find.text('Send Goods'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(selected, 1);
    });
  });

  group('ZOdometerText', () {
    testWidgets('swaps value with animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ZOdometerText('₹142'))),
      );
      expect(find.text('₹142'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ZOdometerText('₹162'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹162'), findsOneWidget);
      expect(find.text('₹142'), findsNothing);
    });
  });

  group('ZPlateBadge & ZPinPill', () {
    testWidgets('render plate and pin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZPlateBadge(plate: 'ka 01 ab 4921'),
                ZPinPill(pin: '4829'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('KA 01 AB 4921'), findsOneWidget);
      expect(find.text('PIN 4829'), findsOneWidget);
    });
  });

  group('ZTicketCard', () {
    testWidgets('renders top and bottom sections with perforation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZTicketCard(
              top: Text('Invoice header'),
              bottom: Text('Ledger'),
            ),
          ),
        ),
      );
      expect(find.text('Invoice header'), findsOneWidget);
      expect(find.text('Ledger'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets); // perforation painter
    });
  });

  group('ZCouponCard', () {
    testWidgets('shows code, savings and fires action', (tester) async {
      var applied = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZCouponCard(
              code: 'NAMMA50',
              title: '50% off up to ₹40',
              savingsLabel: 'Save ₹40',
              onAction: () => applied = true,
            ),
          ),
        ),
      );
      expect(find.text('NAMMA50'), findsOneWidget);
      expect(find.text('Save ₹40'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      expect(applied, isTrue);
    });
  });

  group('ZRouteTimeline', () {
    testWidgets('shows pickup and drop', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZRouteTimeline(
              pickup: '100 Feet Rd, Indiranagar',
              drop: 'MG Road Metro',
            ),
          ),
        ),
      );
      expect(find.text('100 Feet Rd, Indiranagar'), findsOneWidget);
      expect(find.text('MG Road Metro'), findsOneWidget);
    });
  });

  group('ZRadarPulse', () {
    testWidgets('builds and animates without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ZRadarPulse())),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ZRadarPulse), findsOneWidget);
      // Dispose cleanly (controller cancelled in state dispose).
    });
  });

  group('ZQuickVehicleCard', () {
    testWidgets('renders label, eta and fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZQuickVehicleCard(
              label: 'Auto',
              assetName: 'veh_auto',
              etaLabel: '2m',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('2m'), findsOneWidget);
      await tester.tap(find.text('Auto'));
      expect(tapped, isTrue);
    });
  });

  group('ZSkeleton shimmer', () {
    testWidgets('builds and pulses', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ZSkeleton(height: 40))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ZSkeleton), findsOneWidget);
    });
  });
}
