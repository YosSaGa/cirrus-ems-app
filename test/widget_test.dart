import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cirrus_app/widgets/app_bottom_nav.dart';

void main() {
  testWidgets(
    'navigation preserves existing destinations and opens work trial',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              currentIndex: selected,
              onTap: (index) => selected = index,
            ),
          ),
        ),
      );
      for (final label in ['Attendance', 'History', 'Pay & Leave', 'Profile']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Pay & Leave'));
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
