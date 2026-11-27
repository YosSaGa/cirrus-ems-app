// claude_prompt.txt (v161 -- Complete Attendance Photo Upload & Camera
// Switching Integration, §9 "Use a deterministic mock camera platform
// where practical"): a minimal, deterministic `CameraPlatform`
// implementation for widget tests -- `flutter_test`'s default binding
// registers NO real camera platform at all (confirmed empirically in v158:
// `availableCameras()` just hangs/throws), so testing front/rear switching,
// "disabled with one camera", "concurrent switch prevented", and
// initialization-failure handling all require a real, controllable fake
// standing in for the real Android/iOS/Web implementation.
//
// Built directly from `CameraController._initializeWithDescription()`'s own
// source (camera-0.12.2/lib/src/camera_controller.dart) to match its exact
// call sequence: `createCameraWithSettings` -> subscribe to
// `onCameraInitialized(id)`/`onCameraError(id)` -> `initializeCamera(id,
// ...)` -> await the `onCameraInitialized` event. Every other
// `CameraPlatform` method not needed by `AttendanceCameraScreen` keeps the
// base class's own `UnimplementedError` default (confirmed: this file only
// overrides what `initialize()`/`takePicture()`/`dispose()`/`CameraPreview`
// actually call).
//
// IMPORTANT: `onCameraError(id).first` is awaited by the real controller
// with no error handler, so `.first` on a stream that ever closes without
// emitting throws an uncaught `StateError("No element")` the moment it
// closes. A naive per-camera `StreamController` that gets `close()`-d in
// `dispose()` triggers exactly that (confirmed empirically: every test
// failed with this error until the fix below). Real platform
// implementations avoid it by keeping one shared, never-closed,
// app-lifetime event stream per event type and filtering by camera id --
// `dispose()` only tears down native resources, never the Dart-side
// stream. Mirrored here with two shared broadcast controllers.
import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({required this.cameras});

  List<CameraDescription> cameras;

  /// Set to a non-null [PlatformException] to make the NEXT
  /// `createCamera`/`initializeCamera` call fail -- cleared automatically
  /// after it fires once, so a later retry/switch can succeed normally.
  PlatformException? failNextInit;

  /// Bytes `takePicture()` returns wrapped in an [XFile] -- a tiny, valid
  /// in-memory JPEG is unnecessary for these tests, since nothing here
  /// decodes the image; any non-empty byte list is sufficient.
  List<int> nextCaptureBytes = const [1, 2, 3];

  /// Delay before the NEXT `initializeCamera()` call fires its
  /// `CameraInitializedEvent` -- defaults to zero (resolves within the
  /// same microtask-drain pass, which is what every other scenario here
  /// relies on). A test that needs to observe the transient
  /// "initializing" frame itself (real `pump()` only renders a frame
  /// after draining pending microtasks, so a zero-delay chain completes
  /// and reverts to `ready` before that frame is ever built -- confirmed
  /// empirically) sets this to a real, nonzero duration and advances the
  /// clock explicitly via `tester.pump(duration)`.
  Duration initDelay = Duration.zero;

  int _nextCameraId = 0;
  final Map<int, CameraDescription> _descriptionsById = {};

  final _initController =
      StreamController<_IdEvent<CameraInitializedEvent>>.broadcast();
  final _errorController =
      StreamController<_IdEvent<CameraErrorEvent>>.broadcast();

  final List<int> disposedCameraIds = [];
  final List<CameraDescription> createdDescriptions = [];
  int createCameraCallCount = 0;
  int takePictureCallCount = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async {
    createCameraCallCount++;
    createdDescriptions.add(cameraDescription);
    final id = _nextCameraId++;
    _descriptionsById[id] = cameraDescription;
    return id;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initController.stream
          .where((event) => event.cameraId == cameraId)
          .map((event) => event.payload);

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errorController
      .stream
      .where((event) => event.cameraId == cameraId)
      .map((event) => event.payload);

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    final failure = failNextInit;
    if (failure != null) {
      failNextInit = null;
      throw failure;
    }
    // Fire the initialized event -- on the next microtask by default (so
    // the many scenarios that don't care about mid-switch timing settle
    // with a couple of bare `pump()` calls), or after a real `initDelay`
    // when a test needs to observe the transient state itself. The real
    // controller subscribes to `onCameraInitialized(id).first` BEFORE
    // calling this method, so the listener is already attached either way.
    void fire() {
      _initController.add(
        _IdEvent(
          cameraId,
          const CameraInitializedEvent(
            0,
            1920,
            1080,
            ExposureMode.auto,
            true,
            FocusMode.auto,
            true,
          ),
        ),
      );
    }

    if (initDelay > Duration.zero) {
      Future<void>.delayed(initDelay, fire);
    } else {
      scheduleMicrotask(fire);
    }
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    takePictureCallCount++;
    return XFile.fromData(
      Uint8List.fromList(nextCaptureBytes),
      name: 'fake.jpg',
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposedCameraIds.add(cameraId);
    _descriptionsById.remove(cameraId);
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.shrink();
}

class _IdEvent<T> {
  const _IdEvent(this.cameraId, this.payload);

  final int cameraId;
  final T payload;
}
