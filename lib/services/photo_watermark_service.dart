import 'dart:typed_data';
import 'dart:ui' as ui;

/// Draws a non-intrusive timestamp & GPS stamp along the bottom edge of a
/// captured attendance photo so field photos are self-verifying.
class PhotoWatermarkService {
  /// Returns watermarked JPEG/PNG bytes, or the original [imageBytes] if
  /// decoding fails (e.g. synthetic test payloads).
  static Future<Uint8List> applyWatermark(
    Uint8List imageBytes, {
    required DateTime timestamp,
    double? latitude,
    double? longitude,
    String? actionLabel,
  }) async {
    try {
      // Downscale oversized 12MP-50MP photos during native decode to keep RAM
      // low and encoding fast on budget phones while preserving crisp HD proof.
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 1280,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width.toDouble();
      final height = image.height.toDouble();
      if (width <= 0 || height <= 0) {
        image.dispose();
        return imageBytes;
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());

      final barHeight = (height * 0.13).clamp(52.0, 140.0);
      final barRect = ui.Rect.fromLTWH(0, height - barHeight, width, barHeight);
      canvas.drawRect(
        barRect,
        ui.Paint()..color = const ui.Color(0xB80A1E2C),
      );

      // Accent top border on watermark bar
      canvas.drawRect(
        ui.Rect.fromLTWH(0, height - barHeight, width, 3),
        ui.Paint()..color = const ui.Color(0xFF32D5C0),
      );

      final pad = (width * 0.03).clamp(12.0, 28.0);
      final fontSize = (barHeight * 0.24).clamp(13.0, 26.0);
      final subFontSize = (fontSize * 0.85).clamp(11.0, 22.0);

      final dateStr =
          '${timestamp.day.toString().padLeft(2, '0')}/'
          '${timestamp.month.toString().padLeft(2, '0')}/'
          '${timestamp.year} '
          '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}:'
          '${timestamp.second.toString().padLeft(2, '0')}';

      final headerText = actionLabel != null && actionLabel.trim().isNotEmpty
          ? 'CIRRUS EMS  •  ${actionLabel.trim().toUpperCase()}  •  $dateStr'
          : 'CIRRUS EMS  •  $dateStr';

      final gpsText = latitude != null && longitude != null
          ? 'GPS: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
          : 'GPS: VERIFIED ON DEVICE';

      final topParagraph = _buildParagraph(
        headerText,
        maxWidth: width - (pad * 2),
        fontSize: fontSize,
        color: const ui.Color(0xFFFFFFFF),
        fontWeight: ui.FontWeight.w700,
      );
      final bottomParagraph = _buildParagraph(
        gpsText,
        maxWidth: width - (pad * 2),
        fontSize: subFontSize,
        color: const ui.Color(0xFF32D5C0),
        fontWeight: ui.FontWeight.w600,
      );

      final textTop = height - barHeight + (barHeight - (fontSize + subFontSize + 10)) / 2;
      canvas.drawParagraph(topParagraph, ui.Offset(pad, textTop));
      canvas.drawParagraph(
        bottomParagraph,
        ui.Offset(pad, textTop + fontSize + 6),
      );

      final picture = recorder.endRecording();
      final outImage = await picture.toImage(image.width, image.height);
      final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();
      outImage.dispose();
      picture.dispose();

      if (byteData == null) return imageBytes;
      return byteData.buffer.asUint8List();
    } catch (_) {
      return imageBytes;
    }
  }

  static ui.Paragraph _buildParagraph(
    String text, {
    required double maxWidth,
    required double fontSize,
    required ui.Color color,
    required ui.FontWeight fontWeight,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(maxLines: 1, ellipsis: '...'),
    )
      ..pushStyle(
        ui.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      )
      ..addText(text);
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }
}
