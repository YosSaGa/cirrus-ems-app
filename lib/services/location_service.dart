import 'package:geolocator/geolocator.dart';

// claude_prompt.txt (Complete GPS Integration for App Attendance): a single,
// narrowly-scoped one-shot location capture, deliberately kept separate from
// AttendanceService -- that service already accepted optional
// latitude/longitude/accuracy parameters before this task (unchanged here),
// but nothing in this codebase previously captured a real device location to
// pass into them. This file owns the device/permission/platform concern;
// AttendanceService remains purely an HTTP + persistence concern.
//
// Every failure mode this task lists (permission denied, permission
// permanently denied, location services disabled, acquisition timeout,
// acquisition failure) is caught here and turned into a `null` return --
// never a thrown exception -- so a caller can always proceed with NULL GPS
// values without its own try/catch. Permission is requested via
// `Geolocator.requestPermission()` only when the OS has not already made a
// permanent decision; once denied forever, this method never prompts again
// (that is `Geolocator`'s own platform-level behavior, not something this
// file re-implements), satisfying "do not repeatedly show permission
// dialogs".
class CapturedLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;

  const CapturedLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
}

class LocationService {
  /// Captures the current device location once. Returns `null` on ANY
  /// failure -- permission denied or permanently denied, location services
  /// disabled, acquisition timeout, or any other acquisition error -- never
  /// throws. Never performs continuous or background location tracking:
  /// exactly one `getCurrentPosition()` call per invocation.
  static Future<CapturedLocation?> captureCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Only reaches the OS permission dialog when the OS itself has not
        // already made a permanent decision -- `requestPermission()` is a
        // no-op prompt-wise once `deniedForever` is already in effect.
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));

      return CapturedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (_) {
      // Covers LocationServiceDisabledException, permission exceptions,
      // TimeoutException (from the .timeout() above), and any other
      // platform-specific acquisition failure -- GPS is optional, so none
      // of these should ever block Attendance submission.
      return null;
    }
  }
}
