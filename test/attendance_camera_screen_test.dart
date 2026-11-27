// claude_prompt.txt (v157 -- Flutter Camera Capture Integration, §7
// "Test permission denial and camera initialization failure where
// practical"): `flutter_test`'s default test binding registers no platform
// implementation for the `camera` plugin's method channel at all -- calling
// `availableCameras()` inside a widget test therefore reliably throws
// (a `MissingPluginException`, not anything this test deliberately mocks),
// which is exactly the "no camera plugin available" failure
// `AttendanceCameraScreen` must already handle gracefully per its own §2
// "Camera unavailable" UI state requirement. This gives a real, repeatable
// exercise of that failure path without needing to fabricate a fake
// platform-channel response whose shape might not match the real plugin's
// -- the one case this environment cannot actually test is the SUCCESS
// path (a real initialized camera), which would require a real device or
// browser; see PROGRESS_LOG.md's own v157 report for why that is reported
// as not run, not assumed to pass.
//
// claude_prompt.txt (v158 -- Fix Camera Screen Widget Test Pumping
// Strategy): every `pumpAndSettle()` below was replaced with deterministic,
// fixed pumping. The root cause: `_Phase.initializing` (and, briefly,
// `_Phase.ready`/`_Phase.capturing`) renders an indeterminate
// `CircularProgressIndicator`, which schedules a new animation frame every
// tick forever -- `pumpAndSettle()` waits for frame scheduling to stop
// entirely, which never happens while that indicator is on screen, so it
// reliably times out. None of the three tests actually need the animation
// to settle: each only needs specific, known async steps (the
// `availableCameras()` rejection, a route's push/pop transition) to finish,
// which a fixed number of `pump()` calls (optionally with an explicit
// duration) already guarantees deterministically.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cirrus_app/screens/attendance_camera_screen.dart';
import 'package:cirrus_app/widgets/status_banner.dart';

void main() {
  testWidgets(
    'AttendanceCameraScreen shows the Camera Unavailable state when no '
    'camera plugin implementation is registered (the default flutter_test '
    'environment)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AttendanceCameraScreen()),
      );

      // claude_prompt.txt (v158): confirmed empirically this round (via a
      // throwaway diagnostic test, since this behavior could not be
      // predicted from source alone) that `availableCameras()` does NOT
      // reject on a plain microtask in this environment -- no number of
      // fake-clock `pump()`/`pump(duration)` calls ever resolves it (10
      // pumps of 50ms each left the screen stuck on "Preparing camera...").
      // It is waiting on the real platform-channel round trip, which only
      // the REAL event loop drives -- `tester.runAsync()` is the
      // documented, deterministic way to let that happen inside a widget
      // test (still a fixed, bounded wait, never an unbounded settle).
      // One `pump()` afterward renders the resulting state update.
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(find.text('Camera Unavailable'), findsOneWidget);
      expect(find.byType(StatusBanner), findsOneWidget);
      // The one affordance this state offers is a way back out -- never a
      // dead end with no actionable control.
      expect(find.text('Cancel'), findsWidgets);
    },
  );

  testWidgets(
    'AttendanceCameraScreen always offers a close/cancel action, even '
    'while still initializing',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AttendanceCameraScreen()),
      );

      // Before the async availableCameras() call has had a chance to
      // settle -- the "initializing" phase.
      await tester.pump();

      expect(find.byTooltip('Cancel'), findsOneWidget);

      // claude_prompt.txt (v158): no trailing pumpAndSettle() -- this test
      // asserts only the initializing phase's own close affordance, and
      // never needs initialization (or its indeterminate progress
      // animation) to finish at all.
    },
  );

  testWidgets(
    'Tapping the close button pops the screen with a null result, never '
    'an Attendance Event submission',
    (tester) async {
      String? poppedRoute;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => const AttendanceCameraScreen(),
                    ),
                  );
                  poppedRoute = result == null ? 'null' : 'non-null';
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      // claude_prompt.txt (v158): fixed-duration pumps for the route
      // transitions instead of pumpAndSettle() -- AttendanceCameraScreen's
      // own initializing-phase CircularProgressIndicator is already on
      // screen by the time the forward transition finishes, and would
      // make pumpAndSettle() time out waiting for an animation that never
      // stops. ~350ms covers MaterialPageRoute's default ~300ms
      // transition in both directions without waiting for anything beyond
      // the transition itself.
      // claude_prompt.txt (v158): a zero-duration pump immediately after
      // each tap lets the tap's gesture recognizer actually resolve and
      // invoke onPressed (confirmed empirically this round -- without it,
      // the subsequent duration-pump's frame still shows the PREVIOUS
      // route, so byTooltip('Cancel') finds nothing) before the
      // duration-pump advances the route transition's own animation clock
      // to completion.
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      // Flush any pending microtasks (the Navigator.pop's own Future
      // resolution that assigns `poppedRoute`) before asserting on it.
      await tester.pump();

      expect(poppedRoute, 'null');
    },
  );
}
