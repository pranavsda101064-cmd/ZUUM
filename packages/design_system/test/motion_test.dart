import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_design_system/design_system.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: ZuumTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('ZAnimatedCounter counts up to the value', (tester) async {
    await tester.pumpWidget(
      wrap(
        ZAnimatedCounter(
          value: 18240,
          format: (value) => ZFormat.inr(value.toInt()),
          style: ZTypography.display,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('₹182.40'), findsOneWidget);
  });

  testWidgets('ZEntrance reveals its child after the delay', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ZEntrance(
          index: 1,
          step: Duration(milliseconds: 40),
          child: Text('captain'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('captain'), findsOneWidget);
  });

  testWidgets('ZBottomNav reports taps and shows every label', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ZuumTheme.light(),
        home: Scaffold(
          body: ZBottomNav(
            selectedIndex: 1,
            onSelected: (index) => selected = index,
            items: const [
              ZBottomNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Home',
              ),
              ZBottomNavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'Earnings',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    await tester.tap(find.text('Home'));
    expect(selected, 0);
  });

  testWidgets('ZBrandSplash reveals the brand and optional badge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const ZBrandSplash(
          badge: 'PARTNER',
          kannada: 'ಸುಸ್ವಾಗತ',
          tagline: 'Earn on every street in the city.',
          footnote: 'v1.0',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Zuum'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('PARTNER'), findsOneWidget);
    expect(find.text('Earn on every street in the city.'), findsOneWidget);
    expect(find.text('v1.0'), findsOneWidget);
  });

  testWidgets('ZStatCard accepts an animated value widget', (tester) async {
    await tester.pumpWidget(
      wrap(
        ZStatCard(
          label: 'Net today',
          value: '₹0',
          valueWidget: ZAnimatedCounter(
            value: 5000,
            format: (value) => ZFormat.inr(value.toInt()),
            style: ZTypography.numericLg.copyWith(fontSize: 20),
          ),
          caption: '1 trip',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('NET TODAY'), findsOneWidget);
    expect(find.text('₹50'), findsOneWidget);
  });
}
