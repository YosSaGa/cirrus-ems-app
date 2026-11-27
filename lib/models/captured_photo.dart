import 'dart:typed_data';

class CapturedPhoto {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const CapturedPhoto({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}
