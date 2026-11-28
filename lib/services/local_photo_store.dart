import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/captured_photo.dart';

/// Persists captured attendance photos to the app documents directory
/// (not cache). One file per uploadRequestId. Not used on Web.
class LocalPhotoStore {
  LocalPhotoStore._();

  /// Test-only override for the documents directory.
  static Future<Directory> Function()? debugDirectoryOverride;

  static String _sanitizeId(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return cleaned.isEmpty ? 'photo' : cleaned;
  }

  static Future<Directory> _photosDirectory() async {
    final base = debugDirectoryOverride != null
        ? await debugDirectoryOverride!()
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}attendance_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _extensionFor(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }

  /// Saves photo bytes and returns the absolute file path.
  static Future<String> save(
    String uploadRequestId,
    CapturedPhoto photo,
  ) async {
    final dir = await _photosDirectory();
    final safeId = _sanitizeId(uploadRequestId);
    final file = File(
      '${dir.path}${Platform.pathSeparator}$safeId.${_extensionFor(photo.mimeType)}',
    );
    await file.writeAsBytes(photo.bytes, flush: true);
    return file.path;
  }

  /// Returns null on any failure (missing / empty / read error).
  static Future<CapturedPhoto?> read(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final lower = filePath.toLowerCase();
      final mimeType = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : lower.endsWith('.gif')
          ? 'image/gif'
          : 'image/jpeg';
      return CapturedPhoto(
        bytes: bytes,
        fileName: filePath.split(RegExp(r'[/\\]')).last,
        mimeType: mimeType,
      );
    } catch (_) {
      return null;
    }
  }

  /// Best-effort delete — never throws.
  static Future<void> delete(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }
}
