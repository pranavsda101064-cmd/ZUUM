import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_design_system/design_system.dart';

void main() {
  testWidgets('ZNavigationBanner shows maneuver, instruction and distance',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZuumTheme.light(),
        home: const Scaffold(
          body: ZNavigationBanner(
            maneuverType: 10,
            instruction: 'Turn right onto MG Road',
            distanceLabel: '240 m',
            remainingLabel: '3.2 km · 12 min',
          ),
        ),
      ),
    );
    expect(find.text('Turn right onto MG Road'), findsOneWidget);
    expect(find.text('240 m'), findsOneWidget);
    expect(find.byIcon(Icons.turn_right_rounded), findsOneWidget);
    expect(find.text('3.2 km · 12 min'), findsOneWidget);
  });

  test('maneuver icons cover turns, roundabouts and arrival', () {
    expect(ZNavigationBanner.iconFor(9), Icons.turn_right_rounded);
    expect(ZNavigationBanner.iconFor(15), Icons.turn_left_rounded);
    expect(ZNavigationBanner.iconFor(12), Icons.u_turn_right_rounded);
    expect(ZNavigationBanner.iconFor(26), Icons.roundabout_right_rounded);
    expect(ZNavigationBanner.iconFor(4), Icons.flag_rounded);
    expect(ZNavigationBanner.iconFor(1), Icons.navigation_rounded);
    expect(ZNavigationBanner.iconFor(999), Icons.straight_rounded);
  });

  testWidgets('ZMapStatusChip labels degraded and live routes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZuumTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              ZMapStatusChip(degraded: true),
              ZMapStatusChip(degraded: false, provider: 'valhalla'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Approximate route'), findsOneWidget);
    expect(find.text('Live route'), findsOneWidget);
  });

  testWidgets('ZMapView renders the deterministic canvas fallback in tests',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZuumTheme.light(),
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: ZMapView(
              center: const ZMapCenter(12.9352, 77.6245),
              route: const ZMapRoute([
                ZMapCenter(12.9352, 77.6245),
                ZMapCenter(12.9500, 77.6300),
                ZMapCenter(12.9716, 77.5946),
              ]),
              markers: const [
                ZMapMarker(12.9352, 77.6245, kind: ZMapMarkerKind.pickup),
                ZMapMarker(12.9716, 77.5946, kind: ZMapMarkerKind.drop),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ZMapView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
  });
}
