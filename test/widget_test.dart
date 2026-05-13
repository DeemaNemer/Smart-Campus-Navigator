import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_campus_app/main.dart';

void main() {
  testWidgets('Smart Campus app renders splash screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: SmartCampusApp(),
      ),
    );

    expect(find.text('Smart Campus'), findsOneWidget);
    expect(find.text('Navigator'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });
}
