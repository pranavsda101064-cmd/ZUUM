import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuum_admin/main.dart';

void main() {
  testWidgets('signed-out admins land on the ops login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AdminRoot());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ops sign in'), findsOneWidget);
    expect(find.text('Enter command center'), findsOneWidget);
  });
}
