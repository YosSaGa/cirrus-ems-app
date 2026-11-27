// claude_prompt.txt (v161 -- Complete Attendance Photo Upload & Camera
// Switching Integration, §9 "Camera" 1-8): deterministic coverage of
// front/rear switching using `FakeCameraPlatform` (test/support/) --
// `CameraPlatform.instance` is a real, swappable seam the `camera` plugin
// itself provides for exactly this purpose (`PlatformInterface.verify`),
// not something this round invented. Scenario 8 ("existing capture,
// retake, confirm, cancel behavior remains correct") is folded in as its
// own test using the same fake, confirming v157's original behavior
// survived this round's refactor (`_openController` extraction) intact.
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cirrus_app/models/captured_photo.dart';
import 'package:cirrus_app/screens/attendance_camera_screen.dart';

import 'support/fake_camera_platform.dart';

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);
const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

FakeCameraPlatform _install(List<CameraDescription> cameras) {
  final fake = FakeCameraPlatform(cameras: cameras);
  CameraPlatform.instance = fake;
  return fake;
}

// A minimal valid 1x1 transparent PNG -- `AttendanceCameraScreen`'s preview
// phase renders the captured bytes through `Image.memory`, which decodes
// them as a real image; arbitrary placeholder bytes like `[9, 9, 9, 9]`
// throw an "Invalid image data" exception during that decode (confirmed
// empirically), so scenario 8 needs genuinely decodable bytes.
const _validPngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

void main() {
  testWidgets('1. Front camera is selected by default when available', (
    tester,
  ) async {
    final fake = _install([_back, _front]);

    await tester.pumpWidget(const MaterialApp(home: AttendanceCameraScreen()));
    await tester.pump();
    await tester.pump();

    expect(fake.createdDescriptions, hasLength(1));
    expect(
      fake.createdDescriptions.single.lensDirection,
      CameraLensDirection.front,
    );
    expect(find.byTooltip('Switch camera'), findsOneWidget);
  });

  testWidgets('2. Rear camera can be selected via the switch control', (
    tester,
  ) async {
    final fake = _install([_front, _back]);

    await tester.pumpWidget(const MaterialApp(home: AttendanceCameraScreen()));
    await tester.pump();
    await tester.pump();
    expect(
      fake.createdDescriptions.single.lensDirection,
      CameraLensDirection.front,
    );

    await tester.tap(find.byTooltip('Switch camera'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(fake.createdDescriptions, hasLength(2));
    expect(
      fake.createdDescriptions.last.lensDirection,
      CameraLensDirection.back,
    );
  });

  testWidgets(
    '3. The switch control is hidden (not merely disabled) when only one camera exists',
    (tester) async {
      _install([_front]);

      await tester.pumpWidget(
        const MaterialApp(home: AttendanceCameraScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('Switch camera'), findsNothing);
    },
  );

  testWidgets(
    '4. Concurrent switch requests are prevented -- two rapid taps only switch once',
    (tester) async {
      final fake = _install([_front, _back]);

      await tester.pumpWidget(
        const MaterialApp(home: AttendanceCameraScreen()),
      );
      await tester.pump();
      await tester.pump();
      expect(fake.createCameraCallCount, 1);

      // `tester.tap()` is deliberately NOT used here: awaiting it drains
      // the microtask queue, and this fake's entire controller-open chain
      // is pure microtasks (no real delay) -- confirmed empirically, two
      // sequentially-awaited taps let the first switch fully resolve
      // (back to `ready`, `_switchingCamera` reset) before the second tap
      // ever dispatches, so the "concurrent" taps were actually
      // sequential and both succeeded. Invoking the same `onPressed`
      // callback twice back-to-back with NO await between synchronously
      // runs both calls' guard checks before either one's first `await`
      // suspends, which is the only way to deterministically exercise
      // `_switchingCamera` itself.
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Switch camera'),
          matching: find.byType(IconButton),
        ),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        fake.createCameraCallCount,
        2,
        reason:
            'exactly one switch (front->back) must have happened, never two',
      );
    },
  );

  testWidgets('5. Capture is disabled while switching cameras', (tester) async {
    final fake = _install([_front, _back]);

    await tester.pumpWidget(const MaterialApp(home: AttendanceCameraScreen()));
    await tester.pump();
    await tester.pump();

    // A bare `pump()` first drains pending microtasks (where the fake's
    // zero-delay resolution chain would run to completion) and only
    // THEN builds the frame -- so with the default zero delay, a
    // single pump() after triggering the switch shows the FINAL state,
    // never the transient one (confirmed empirically). Giving the next
    // switch a real, nonzero delay keeps it pending across one pump(),
    // making the "initializing" frame itself observable.
    fake.initDelay = const Duration(milliseconds: 50);

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Switch camera'),
        matching: find.byType(IconButton),
      ),
    );
    button.onPressed!();
    await tester.pump(); // mid-switch: _phase is now `initializing`

    // The entire CameraPreview/shutter UI is replaced by the
    // initializing spinner during a switch -- capture is structurally
    // unreachable, not merely gated behind a disabled button.
    expect(find.bySemanticsLabel('Capture photo'), findsNothing);
    expect(find.text('Preparing camera...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(fake.takePictureCallCount, 0);
  });

  testWidgets(
    '6. The old controller is disposed before the replacement is created',
    (tester) async {
      final fake = _install([_front, _back]);

      await tester.pumpWidget(
        const MaterialApp(home: AttendanceCameraScreen()),
      );
      await tester.pump();
      await tester.pump();
      expect(fake.disposedCameraIds, isEmpty);

      await tester.tap(find.byTooltip('Switch camera'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        fake.disposedCameraIds,
        [0],
        reason: 'the original (front, id 0) controller must be disposed exactly once',
      );
      expect(fake.createCameraCallCount, 2);
    },
  );

  testWidgets(
    '7. A switching failure is handled -- shows the failure state, does not crash',
    (tester) async {
      final fake = _install([_front, _back]);

      await tester.pumpWidget(
        const MaterialApp(home: AttendanceCameraScreen()),
      );
      await tester.pump();
      await tester.pump();

      fake.failNextInit = PlatformException(
        code: 'error',
        message: 'hardware busy',
      );

      await tester.tap(find.byTooltip('Switch camera'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Capture Failed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    },
  );

  testWidgets(
    '7b. An initial camera-permission failure is handled (distinct from a generic failure)',
    (tester) async {
      final fake = _install([_front]);
      fake.failNextInit = PlatformException(
        code: 'CameraAccessDenied',
        message: 'denied',
      );

      await tester.pumpWidget(
        const MaterialApp(home: AttendanceCameraScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Camera Permission Needed'), findsOneWidget);
    },
  );

  testWidgets(
    '8. Existing capture, retake, confirm, and cancel behavior remains correct after the switching refactor',
    (tester) async {
      final fake = _install([_front, _back]);
      fake.nextCaptureBytes = _validPngBytes;

      CapturedPhoto? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<CapturedPhoto>(
                    MaterialPageRoute(
                      builder: (_) => const AttendanceCameraScreen(),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump();

      // Capture.
      await tester.tap(find.bySemanticsLabel('Capture photo'));
      await tester.pump();
      await tester.pump();
      expect(
        find.byType(Image),
        findsOneWidget,
        reason: 'preview phase shows the captured bytes',
      );
      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Use Photo'), findsOneWidget);

      // Retake -> back to live preview, switch control reappears.
      await tester.tap(find.text('Retake'));
      await tester.pump();
      expect(find.byTooltip('Switch camera'), findsOneWidget);

      // Capture again, then confirm.
      await tester.tap(find.bySemanticsLabel('Capture photo'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Use Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.bytes, _validPngBytes);
      expect(fake.takePictureCallCount, 2);
    },
  );

  testWidgets(
    '8b. Canceling (the close button) returns null -- no photo is handed back',
    (tester) async {
      _install([_front]);

      CapturedPhoto? result = CapturedPhoto(
        bytes: Uint8List.fromList([0]),
        fileName: 'x',
        mimeType: 'image/jpeg',
      );
      var popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<CapturedPhoto>(
                    MaterialPageRoute(
                      builder: (_) => const AttendanceCameraScreen(),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(popped, true);
      expect(result, isNull);
    },
  );
}
