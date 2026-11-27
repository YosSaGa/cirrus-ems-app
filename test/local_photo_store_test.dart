// claude_prompt.txt (v171 -- Flutter Attendance Photo Persistence & Retry
// Implementation §3): `getApplicationDocumentsDirectory()` has no real
// platform implementation registered in a plain `flutter test` VM run
// (path_provider has no web/test-default implementation either) -- tests
// use `LocalPhotoStore.debugDirectoryOverride`, the same
// `@visibleForTesting` static-override pattern this codebase already
// established for `AuthService.debugOverrideClient`/`AttendanceService.
// debugOverrideClient`, substituting a real, disposable
// `Directory.systemTemp.createTempSync()` directory instead of faking the
// platform channel.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:cirrus_app/models/captured_photo.dart';
import 'package:cirrus_app/services/local_photo_store.dart';

Directory? _scratchDir;

void main() {
  setUp(() {
    _scratchDir = Directory.systemTemp.createTempSync(
      'local_photo_store_test_',
    );
    LocalPhotoStore.debugDirectoryOverride = () async => _scratchDir!;
  });

  tearDown(() {
    LocalPhotoStore.debugDirectoryOverride = null;
    _scratchDir?.deleteSync(recursive: true);
  });

  test('save writes the photo bytes to a file under attendance_photos/ named by uploadRequestId', () async {
    final photo = CapturedPhoto(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'ignored.jpg',
      mimeType: 'image/jpeg',
    );

    final path = await LocalPhotoStore.save('upload-123', photo);

    expect(path, contains('attendance_photos'));
    expect(path, endsWith('upload-123.jpg'));
    final bytes = await File(path).readAsBytes();
    expect(bytes, [1, 2, 3, 4]);
  });

  test('save picks the correct extension per MIME type', () async {
    final pngPhoto = CapturedPhoto(
      bytes: Uint8List.fromList([9]),
      fileName: 'x',
      mimeType: 'image/png',
    );
    final path = await LocalPhotoStore.save('upload-png', pngPhoto);
    expect(path, endsWith('.png'));
  });

  test('read returns a CapturedPhoto with the original bytes and the correct mimeType', () async {
    final photo = CapturedPhoto(
      bytes: Uint8List.fromList([5, 6, 7]),
      fileName: 'x',
      mimeType: 'image/jpeg',
    );
    final path = await LocalPhotoStore.save('upload-456', photo);

    final readBack = await LocalPhotoStore.read(path);

    expect(readBack, isNotNull);
    expect(readBack!.bytes, [5, 6, 7]);
    expect(readBack.mimeType, 'image/jpeg');
  });

  test('read returns null for a missing file (never throws)', () async {
    final result = await LocalPhotoStore.read(
      '${_scratchDir!.path}/does-not-exist.jpg',
    );
    expect(result, isNull);
  });

  test('read returns null for an empty (zero-byte, corrupted) file', () async {
    final dir = Directory('${_scratchDir!.path}/attendance_photos');
    dir.createSync(recursive: true);
    final file = File('${dir.path}/corrupted.jpg');
    file.writeAsBytesSync([]);

    final result = await LocalPhotoStore.read(file.path);
    expect(result, isNull);
  });

  test('delete removes an existing file', () async {
    final photo = CapturedPhoto(
      bytes: Uint8List.fromList([1]),
      fileName: 'x',
      mimeType: 'image/jpeg',
    );
    final path = await LocalPhotoStore.save('upload-789', photo);
    expect(File(path).existsSync(), true);

    await LocalPhotoStore.delete(path);

    expect(File(path).existsSync(), false);
  });

  test('delete on a missing file is a safe no-op (never throws)', () async {
    await LocalPhotoStore.delete('${_scratchDir!.path}/never-existed.jpg');
    // Reaching here without throwing is the assertion.
  });
}
