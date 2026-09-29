import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:content_filter_vpn/screens/clock_screen.dart';

void main() {
  testWidgets('clock camouflage renders normally', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'mindguard_clock_setup_complete': true,
    });

    await tester.pumpWidget(
      const MaterialApp(home: ClockScreen()),
    );
    await tester.pump();

    expect(find.byType(ClockScreen), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
    expect(find.textContaining(':'), findsOneWidget);
  });
}
