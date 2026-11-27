import 'package:cirrus_app/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    int index, {
    bool reduced = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            bottomNavigationBar: AppBottomNav(
              currentIndex: index,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  double bubbleX(WidgetTester tester) =>
      tester.getCenter(find.byKey(const Key('nav-selection-bubble'))).dx;

  double bubbleY(WidgetTester tester) =>
      tester.getCenter(find.byKey(const Key('nav-selection-bubble'))).dy;

  testWidgets('selection moves continuously and retargets rapid changes', (
    tester,
  ) async {
    await show(tester, 0);
    final start = bubbleX(tester);
    await show(tester, 3);
    await tester.pump(const Duration(milliseconds: 100));
    final moving = bubbleX(tester);
    expect(moving, greaterThan(start));
    await show(tester, 1);
    expect(bubbleX(tester), closeTo(moving, 0.1));
    await tester.pumpAndSettle();
    final end = bubbleX(tester);
    expect(end, greaterThan(start));
    expect(end, lessThan(moving));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bubble sinks down during transition and pops back up', (
    tester,
  ) async {
    await show(tester, 0);
    final startY = bubbleY(tester);

    // Switch from 0 to 2
    await show(tester, 2);
    // Mid-transition (~180ms of 360ms)
    await tester.pump(const Duration(milliseconds: 180));
    final midY = bubbleY(tester);
    // Sinks down vertically into the notch
    expect(midY, greaterThan(startY));

    // Settles at destination
    await tester.pumpAndSettle();
    final endY = bubbleY(tester);
    expect(endY, closeTo(startY, 0.5));
  });

  testWidgets('tapping active item triggers bounce sink and restore', (
    tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onTap: (_) => taps++,
          ),
        ),
      ),
    );

    final restingY = bubbleY(tester);
    await tester.tap(find.byKey(const ValueKey('nav-item-0')));
    await tester.pump();
    expect(taps, 1);

    // Mid bounce (120ms of 240ms)
    await tester.pump(const Duration(milliseconds: 120));
    final bouncedY = bubbleY(tester);
    expect(bouncedY, greaterThan(restingY));

    await tester.pumpAndSettle();
    expect(bubbleY(tester), closeTo(restingY, 0.5));
  });

  testWidgets('no duplicate icon widget exists for the active tab', (
    tester,
  ) async {
    await show(tester, 0);
    // Attendance only appears once in the entire tree (in the floating bubble)
    expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);

    // Switch to Profile (index 3)
    await show(tester, 3);
    await tester.pumpAndSettle();
    // Profile only appears once in the entire tree (in the floating bubble)
    expect(find.byIcon(Icons.account_circle_rounded), findsOneWidget);
    // Attendance now only appears once in the row
    expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
  });

  testWidgets(
    'reduced motion updates immediately and taps keep destination indices',
    (tester) async {
      await show(tester, 0, reduced: true);
      final start = bubbleX(tester);
      await show(tester, 3, reduced: true);
      await tester.pump();
      expect(bubbleX(tester), greaterThan(start));
      expect(tester.binding.hasScheduledFrame, isFalse);
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              currentIndex: 0,
              onTap: (index) => selected = index,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('nav-item-2')));
      expect(selected, 2);
    },
  );
}
