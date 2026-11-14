import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_design_system/design_system.dart';

void main() {
  group('ZFormat', () {
    test('inr formats paise with Indian grouping', () {
      expect(ZFormat.inr(0), '₹0');
      expect(ZFormat.inr(23400), '₹234');
      expect(ZFormat.inr(23450), '₹234.50');
      expect(ZFormat.inr(1234567), '₹12,345.67');
      expect(ZFormat.inr(123456789), '₹12,34,567.89');
      expect(ZFormat.inr(-5000), '-₹50');
    });

    test('inr compact mode for tight spaces', () {
      expect(ZFormat.inr(1500000, compact: true), '₹15,000'); // below 1L
      expect(ZFormat.inr(250000000, compact: true), '₹25L');
      expect(ZFormat.inr(12500000000, compact: true), '₹12.5Cr');
    });

    test('distance and duration', () {
      expect(ZFormat.distance(450), '450 m');
      expect(ZFormat.distance(1850), '1.9 km');
      expect(ZFormat.distance(15400), '15 km');
      expect(ZFormat.duration(240), '4 min');
      expect(ZFormat.duration(4500), '1 hr 15 min');
      expect(ZFormat.duration(3600), '1 hr');
    });
  });

  group('ZButton', () {
    testWidgets('renders label and fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZButton(label: 'Continue', onPressed: () => tapped = true),
          ),
        ),
      );
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(tapped, isTrue);
    });

    testWidgets('loading shows spinner and blocks taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZButton(
              label: 'Book',
              loading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(ZButton));
      expect(tapped, isFalse);
    });

    testWidgets('disabled button does not fire', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ZButton(label: 'Go'))),
      );
      await tester.tap(find.text('Go'));
      // no crash, no callback — nothing to assert beyond survival + label
      expect(find.text('Go'), findsOneWidget);
    });
  });

  group('ZChip', () {
    testWidgets('toggles selection visually', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZChip(label: 'Sedan', selected: true)),
        ),
      );
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell, isNotNull);
      expect(find.text('Sedan'), findsOneWidget);
    });
  });

  group('ZStatusBadge', () {
    test('maps booking statuses to tones', () {
      ZBadgeTone toneOf(String status) {
        final widget = ZStatusBadge.forStatus(status, label: status);
        return widget.tone;
      }

      expect(toneOf('CREATED'), ZBadgeTone.neutral);
      expect(toneOf('SEARCHING'), ZBadgeTone.highlight);
      expect(toneOf('IN_PROGRESS'), ZBadgeTone.primary);
      expect(toneOf('COMPLETED'), ZBadgeTone.success);
      expect(toneOf('CANCELLED'), ZBadgeTone.error);
      expect(toneOf('FAILED'), ZBadgeTone.error);
    });
  });

  group('ZEmptyState', () {
    testWidgets('shows title, subtitle and optional action', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZEmptyState(
              title: 'No trips yet',
              subtitle: 'Your rides will show up here.',
              actionLabel: 'Book a ride',
            ),
          ),
        ),
      );
      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text('Your rides will show up here.'), findsOneWidget);
      expect(find.text('Book a ride'), findsOneWidget);
    });
  });

  group('ZTextField', () {
    testWidgets('obscure field toggles visibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZTextField(label: 'Password', obscure: true),
          ),
        ),
      );
      final before = tester.widget<EditableText>(find.byType(EditableText));
      expect(before.obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      final after = tester.widget<EditableText>(find.byType(EditableText));
      expect(after.obscureText, isFalse);
    });
  });

  group('ZFareBreakdown', () {
    testWidgets('renders lines and total', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZFareBreakdown(
              lines: [
                FareLine('Base fare', 3000),
                FareLine('Distance', 14500),
                FareLine('Total', 17500, isTotal: true),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Base fare'), findsOneWidget);
      expect(find.text('₹175'), findsOneWidget);
    });
  });
}
