import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_strings.dart';
import '../services/app_preferences_service.dart';
import '../theme/app_theme.dart';

enum _CacheCategory { imageMemory, cameraPhotos, documents, otherTemp }

class _CacheBucket {
  _CacheBucket({
    required this.category,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _CacheCategory category;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  int bytes = 0;
  int fileCount = 0;
  bool selected = true;
}

/// Telegram-style Storage & Cache screen with an animated donut ring chart,
/// breakdown by cache source, and selective cache clearing.
class StorageCacheScreen extends StatefulWidget {
  const StorageCacheScreen({super.key});

  @override
  State<StorageCacheScreen> createState() => _StorageCacheScreenState();
}

class _StorageCacheScreenState extends State<StorageCacheScreen> {
  bool _scanning = true;
  bool _clearing = false;
  late final List<_CacheBucket> _buckets;

  @override
  void initState() {
    super.initState();
    _buckets = [
      _CacheBucket(
        category: _CacheCategory.imageMemory,
        color: AppColors.secondary,
        icon: Icons.memory_rounded,
        title: AppStrings.t(
          'Image Memory Cache',
          'แคชรูปในหน่วยความจำ',
          'Cache Memori Imej',
        ),
        subtitle: AppStrings.t(
          'Decoded thumbnails & UI images in RAM',
          'ภาพตัวอย่างและไอคอนที่โหลดค้างไว้ในแรม',
          'Imej pratonton yang disimpan dalam RAM',
        ),
      ),
      _CacheBucket(
        category: _CacheCategory.cameraPhotos,
        color: const Color(0xFF38BDF8),
        icon: Icons.photo_camera_outlined,
        title: AppStrings.t(
          'Temp Camera Photos',
          'ไฟล์รูปถ่ายชั่วคราว',
          'Foto Kamera Sementara',
        ),
        subtitle: AppStrings.t(
          'Temporary preview & compressed camera files',
          'ไฟล์ภาพชั่วคราวจากกล้องก่อนอัปโหลด',
          'Fail foto sementara sebelum muat naik',
        ),
      ),
      _CacheBucket(
        category: _CacheCategory.documents,
        color: const Color(0xFFF59E0B),
        icon: Icons.picture_as_pdf_outlined,
        title: AppStrings.t(
          'PDF & Documents',
          'ไฟล์ PDF และเอกสาร',
          'PDF & Dokumen',
        ),
        subtitle: AppStrings.t(
          'Temporary leave PDF previews & logs',
          'ไฟล์ตัวอย่าง PDF ใบลาและบันทึกชั่วคราว',
          'Pratonton PDF cuti & dokumen sementara',
        ),
      ),
      _CacheBucket(
        category: _CacheCategory.otherTemp,
        color: const Color(0xFF8B5CF6),
        icon: Icons.folder_open_rounded,
        title: AppStrings.t(
          'Other Temp Files',
          'ไฟล์ชั่วคราวอื่นๆ',
          'Fail Sementara Lain',
        ),
        subtitle: AppStrings.t(
          'Miscellaneous OS & HTTP cache files',
          'แคชระบบและการเชื่อมต่อชั่วคราว',
          'Cache sistem & sambungan sementara',
        ),
      ),
    ];
    _scanCache();
  }

  _CacheCategory _classifyExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic')) {
      return _CacheCategory.cameraPhotos;
    }
    if (lower.endsWith('.pdf') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.json') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.tmp')) {
      return _CacheCategory.documents;
    }
    return _CacheCategory.otherTemp;
  }

  Future<List<Directory>> _cacheDirectories() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return const [];
    }
    final dirs = <Directory>[];
    final seenPaths = <String>{};
    for (final getter in [getTemporaryDirectory, getApplicationCacheDirectory]) {
      try {
        final d = await getter();
        if (await d.exists() && seenPaths.add(d.path)) {
          dirs.add(d);
        }
      } catch (_) {}
    }
    return dirs;
  }

  Future<void> _scanCache() async {
    setState(() => _scanning = true);
    final sizes = {for (final b in _buckets) b.category: 0};
    final counts = {for (final b in _buckets) b.category: 0};

    try {
      final imageBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
      sizes[_CacheCategory.imageMemory] = imageBytes;
      counts[_CacheCategory.imageMemory] =
          PaintingBinding.instance.imageCache.currentSize;
    } catch (_) {}

    final dirs = await _cacheDirectories();
    for (final dir in dirs) {
      try {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              final cat = _classifyExtension(entity.path);
              sizes[cat] = (sizes[cat] ?? 0) + stat.size;
              counts[cat] = (counts[cat] ?? 0) + 1;
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      for (final b in _buckets) {
        b.bytes = sizes[b.category] ?? 0;
        b.fileCount = counts[b.category] ?? 0;
      }
      _scanning = false;
    });
  }

  Future<void> _confirmAndClearSelected() async {
    if (_clearing || _scanning || !_hasSelection) return;
    if (AppPreferencesService.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    final sizeText = _formatBytes(_selectedBytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('confirm-clear-cache-dialog'),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        title: Text(
          AppStrings.t(
            'Clear Cache?',
            'ยืนยันการล้างแคช?',
            'Kosongkan Cache?',
          ),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.neutral,
          ),
        ),
        content: Text(
          AppStrings.t(
            'Clear $sizeText of selected temporary cache? Your login session, theme, language, and pending offline photos will not be affected.',
            'ต้องการล้างแคชที่เลือก ($sizeText) ใช่หรือไม่? การล้างนี้จะไม่ทำให้หลุดจากระบบ และไม่ลบธีม ภาษา หรือรูปที่รอส่ง',
            'Kosongkan $sizeText cache sementara yang dipilih? Sesi log masuk, tema, bahasa dan foto tertunda tidak akan terjejas.',
          ),
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('cancel-clear-cache-button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral,
                    side: BorderSide(color: AppColors.cardBorder),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: Text(
                    AppStrings.t('Cancel', 'ยกเลิก', 'Batal'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const Key('confirm-clear-cache-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neutral,
                    foregroundColor: AppColors.onNeutral,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: Text(
                    AppStrings.t('Clear', 'ยืนยันล้าง', 'Kosongkan'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _clearSelected();
    }
  }

  Future<void> _clearSelected() async {
    if (_clearing) return;
    final selectedCats = _buckets
        .where((b) => b.selected)
        .map((b) => b.category)
        .toSet();
    if (selectedCats.isEmpty) return;

    if (AppPreferencesService.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    setState(() => _clearing = true);
    final freedBytes = _selectedBytes;

    try {
      if (selectedCats.contains(_CacheCategory.imageMemory)) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }

      final fileCats = selectedCats
          .where((c) => c != _CacheCategory.imageMemory)
          .toSet();
      if (fileCats.isNotEmpty) {
        final dirs = await _cacheDirectories();
        for (final dir in dirs) {
          try {
            await for (final entity in dir.list(
              recursive: true,
              followLinks: false,
            )) {
              if (entity is File &&
                  fileCats.contains(_classifyExtension(entity.path))) {
                try {
                  await entity.delete();
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
        await _scanCache();
        if (mounted) {
          final freedText = _formatBytes(freedBytes);
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.neutral,
              content: Text(
                AppStrings.t(
                  'Cleared $freedText of cache',
                  'ล้างแคชเรียบร้อย ($freedText)',
                  'Cache dibersihkan ($freedText)',
                ),
                style: TextStyle(color: AppColors.onNeutral),
              ),
            ),
          );
        }
      }
    }
  }

  int get _totalBytes => _buckets.fold<int>(0, (sum, b) => sum + b.bytes);

  int get _selectedBytes =>
      _buckets.where((b) => b.selected).fold<int>(0, (sum, b) => sum + b.bytes);

  bool get _hasSelection => _buckets.any((b) => b.selected);

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      final kb = math.max(1, (bytes / 1024).round());
      return '$kb KB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalBytes;
    final selectedBytes = _selectedBytes;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neutral,
        iconTheme: IconThemeData(color: AppColors.neutral),
        title: Text(
          AppStrings.t(
            'Storage & Cache',
            'พื้นที่จัดเก็บและแคช',
            'Storan & Cache',
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.t('Refresh', 'รีเฟรช', 'Muat semula'),
            onPressed: _scanning || _clearing ? null : _scanCache,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: appContentMaxWidth(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.hero),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neutral.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 184,
                          height: 184,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                key: ValueKey(total),
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 650),
                                curve: Curves.easeOutCubic,
                                builder: (context, progress, _) {
                                  return CustomPaint(
                                    size: const Size(184, 184),
                                    painter: _StorageDonutPainter(
                                      buckets: _buckets,
                                      totalBytes: total,
                                      progress: progress,
                                      trackColor: AppColors.cardBorder,
                                    ),
                                  );
                                },
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _scanning
                                        ? '...'
                                        : _formatBytes(total),
                                    key: const Key('storage-total-label'),
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.neutral,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    total == 0
                                        ? AppStrings.t(
                                            'CLEAN',
                                            'สะอาดแล้ว',
                                            'BERSIH',
                                          )
                                        : AppStrings.t(
                                            'TOTAL CACHE',
                                            'แคชทั้งหมด',
                                            'JUMLAH CACHE',
                                          ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: _buckets
                              .map(
                                (b) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: b.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      b.title,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      AppStrings.t(
                        'CACHE BREAKDOWN',
                        'แหล่งที่มาของแคช',
                        'PECAHAN CACHE',
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.surface),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _buckets.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, color: AppColors.cardBorder),
                          _bucketTile(_buckets[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    key: const Key('storage-clear-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neutral,
                      foregroundColor: AppColors.onNeutral,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: _clearing || _scanning || !_hasSelection
                        ? null
                        : _confirmAndClearSelected,
                    icon: _clearing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onNeutral,
                            ),
                          )
                        : const Icon(Icons.cleaning_services_outlined, size: 20),
                    label: Text(
                      AppStrings.t(
                        'Clear Cache (${_formatBytes(selectedBytes)})',
                        'ล้างแคชที่เลือก (${_formatBytes(selectedBytes)})',
                        'Kosongkan Cache (${_formatBytes(selectedBytes)})',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.t(
                      'Your login session, theme, language, and offline pending photos are kept safe.',
                      'การล้างแคชจะไม่ทำให้หลุดออกจากระบบ และไม่ลบธีม ภาษา หรือรูปที่รอส่ง',
                      'Sesi log masuk, tema, bahasa dan foto tertunda kekal selamat.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bucketTile(_CacheBucket bucket) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.surface),
      onTap: _clearing
          ? null
          : () {
              if (AppPreferencesService.hapticsEnabled) {
                HapticFeedback.selectionClick();
              }
              setState(() => bucket.selected = !bucket.selected);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bucket.selected ? bucket.color : Colors.transparent,
                border: Border.all(
                  color: bucket.selected ? bucket.color : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: bucket.selected
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bucket.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(bucket.icon, size: 18, color: bucket.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bucket.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bucket.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatBytes(bucket.bytes),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageDonutPainter extends CustomPainter {
  _StorageDonutPainter({
    required this.buckets,
    required this.totalBytes,
    required this.progress,
    required this.trackColor,
  });

  final List<_CacheBucket> buckets;
  final int totalBytes;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 20.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (totalBytes <= 0 || progress <= 0) return;

    final nonZero = buckets.where((b) => b.bytes > 0).toList(growable: false);
    if (nonZero.isEmpty) return;

    final gap = nonZero.length > 1 ? 0.045 : 0.0;
    final availableSweep = (2 * math.pi * progress) - (gap * nonZero.length);
    var startAngle = -math.pi / 2;

    for (final b in nonZero) {
      final fraction = b.bytes / totalBytes;
      final sweep = math.max(0.06, availableSweep * fraction);
      final paint = Paint()
        ..color = b.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _StorageDonutPainter oldDelegate) {
    return oldDelegate.totalBytes != totalBytes ||
        oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor;
  }
}
