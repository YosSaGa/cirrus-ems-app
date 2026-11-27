import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Service to download / save files directly to the device storage.
class FileDownloadService {
  FileDownloadService._();

  static const MethodChannel _channel = MethodChannel(
    'com.cirrusgroup.ems/downloader',
  );

  /// Test-only override for mocking download in tests.
  @visibleForTesting
  static Future<String> Function(Uint8List bytes, String filename)?
  debugDownloadOverride;

  /// Saves [bytes] with [filename] directly to the device storage
  /// (e.g. system Downloads folder on Android/Desktop).
  ///
  /// Returns a display path or message describing where the file was saved.
  static Future<String> downloadFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (debugDownloadOverride != null) {
      return debugDownloadOverride!(bytes, filename);
    }

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return filename;
    }

    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<String>('saveToDownloads', {
          'bytes': bytes,
          'filename': filename,
        });
        if (result != null && result.isNotEmpty) {
          return result;
        }
      } catch (_) {
        // Fall through to path_provider fallback below
      }
    }

    // Desktop & Android fallback
    try {
      final Directory? baseDir = Platform.isAndroid
          ? (await getExternalStorageDirectories(
              type: StorageDirectory.downloads,
            ))?.firstOrNull
          : await getDownloadsDirectory();

      final dir = baseDir ?? await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      // Last resort fallback
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }
}
