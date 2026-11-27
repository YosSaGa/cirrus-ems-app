import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_strings.dart';
import '../services/api_client_factory.dart';
import '../services/app_preferences_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';

enum _CheckState { checking, ok, warn, error }

class _CheckItemResult {
  const _CheckItemResult({
    required this.state,
    required this.badge,
    required this.detail,
  });

  final _CheckState state;
  final String badge;
  final String detail;
}

/// Field readiness diagnostic screen for checking live EMS server health,
/// GPS/Location permission, and Camera availability before Check-In.
class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({super.key});

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends State<DeviceCheckScreen> {
  bool _running = false;
  bool _canRequestGps = false;
  bool _needsAppSettings = false;
  DateTime? _lastCheckedAt;

  _CheckItemResult _server = _CheckItemResult(
    state: _CheckState.checking,
    badge: AppStrings.t('CHECKING', 'กำลังตรวจ', 'MENYEMAK'),
    detail: AppStrings.t(
      'Checking connection to Cirrus EMS...',
      'กำลังตรวจสอบการเชื่อมต่อระบบ Cirrus EMS...',
      'Menyemak sambungan ke Cirrus EMS...',
    ),
  );
  _CheckItemResult _gps = _CheckItemResult(
    state: _CheckState.checking,
    badge: AppStrings.t('CHECKING', 'กำลังตรวจ', 'MENYEMAK'),
    detail: AppStrings.t(
      'Checking location services & permission...',
      'กำลังตรวจสอบบริการ GPS และสิทธิ์ตำแหน่ง...',
      'Menyemak perkhidmatan lokasi & kebenaran...',
    ),
  );
  _CheckItemResult _camera = _CheckItemResult(
    state: _CheckState.checking,
    badge: AppStrings.t('CHECKING', 'กำลังตรวจ', 'MENYEMAK'),
    detail: AppStrings.t(
      'Checking device cameras...',
      'กำลังตรวจสอบกล้องในเครื่อง...',
      'Menyemak kamera peranti...',
    ),
  );

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    if (_running) return;
    setState(() {
      _running = true;
      _canRequestGps = false;
      _needsAppSettings = false;
      final checking = AppStrings.t('CHECKING', 'กำลังตรวจ', 'MENYEMAK');
      _server = _CheckItemResult(
        state: _CheckState.checking,
        badge: checking,
        detail: AppStrings.t(
          'Checking connection to Cirrus EMS...',
          'กำลังตรวจสอบการเชื่อมต่อระบบ Cirrus EMS...',
          'Menyemak sambungan ke Cirrus EMS...',
        ),
      );
      _gps = _CheckItemResult(
        state: _CheckState.checking,
        badge: checking,
        detail: AppStrings.t(
          'Checking location services & permission...',
          'กำลังตรวจสอบบริการ GPS และสิทธิ์ตำแหน่ง...',
          'Menyemak perkhidmatan lokasi & kebenaran...',
        ),
      );
      _camera = _CheckItemResult(
        state: _CheckState.checking,
        badge: checking,
        detail: AppStrings.t(
          'Checking device cameras...',
          'กำลังตรวจสอบกล้องในเครื่อง...',
          'Menyemak kamera peranti...',
        ),
      );
    });

    final results = await Future.wait<dynamic>([
      _checkServer(),
      _checkGps(),
      _checkCamera(),
    ]);

    if (!mounted) return;
    final gpsRes = results[1] as ({
      _CheckItemResult result,
      bool canRequest,
      bool openSettings,
    });
    final camRes = results[2] as ({
      _CheckItemResult result,
      bool openSettings,
    });
    setState(() {
      _server = results[0] as _CheckItemResult;
      _gps = gpsRes.result;
      _canRequestGps = gpsRes.canRequest;
      _camera = camRes.result;
      _needsAppSettings = gpsRes.openSettings || camRes.openSettings;
      _lastCheckedAt = DateTime.now();
      _running = false;
    });
  }

  Future<_CheckItemResult> _checkServer() async {
    final client = createApiClient();
    final sw = Stopwatch()..start();
    try {
      final res = await client
          .get(Uri.parse('${AuthService.baseUrl}/health'))
          .timeout(const Duration(seconds: 8));
      sw.stop();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _CheckItemResult(
          state: _CheckState.ok,
          badge: AppStrings.t(
            'ONLINE · ${sw.elapsedMilliseconds} MS',
            'เชื่อมต่อปกติ · ${sw.elapsedMilliseconds} MS',
            'DALAM TALIAN · ${sw.elapsedMilliseconds} MS',
          ),
          detail: AppStrings.t(
            'Connected and responding normally.',
            'เชื่อมต่อระบบและตอบสนองได้ตามปกติ',
            'Disambungkan dan berfungsi normal.',
          ),
        );
      }
      return _CheckItemResult(
        state: _CheckState.error,
        badge: 'HTTP ${res.statusCode}',
        detail: AppStrings.t(
          'Service temporarily unavailable (HTTP ${res.statusCode}).',
          'ระบบขัดข้องชั่วคราว (HTTP ${res.statusCode})',
          'Perkhidmatan terganggu sementara (HTTP ${res.statusCode}).',
        ),
      );
    } catch (_) {
      sw.stop();
      return _CheckItemResult(
        state: _CheckState.error,
        badge: AppStrings.t('OFFLINE', 'เชื่อมต่อไม่ได้', 'LUAR TALIAN'),
        detail: AppStrings.t(
          'Unable to reach server. Check your internet connection.',
          'ไม่สามารถเชื่อมต่อได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
          'Gagal menyambung. Sila semak sambungan internet anda.',
        ),
      );
    } finally {
      client.close();
    }
  }

  Future<({_CheckItemResult result, bool canRequest, bool openSettings})>
  _checkGps() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (
          result: _CheckItemResult(
            state: _CheckState.warn,
            badge: AppStrings.t('GPS OFF', 'GPS ปิดอยู่', 'GPS DIMATIKAN'),
            detail: AppStrings.t(
              'Turn on device Location (GPS) to attach coordinates.',
              'กรุณาเปิด GPS บนมือถือเพื่อให้ระบบบันทึกพิกัดได้',
              'Hidupkan Lokasi (GPS) peranti untuk merekod koordinat.',
            ),
          ),
          canRequest: false,
          openSettings: true,
        );
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        return (
          result: _CheckItemResult(
            state: _CheckState.ok,
            badge: AppStrings.t('READY', 'พร้อมใช้งาน', 'SEDIA'),
            detail: AppStrings.t(
              'Location services and permission granted.',
              'เปิดใช้งาน GPS และอนุญาตสิทธิ์ตำแหน่งแล้ว',
              'Perkhidmatan lokasi & kebenaran diberikan.',
            ),
          ),
          canRequest: false,
          openSettings: false,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return (
          result: _CheckItemResult(
            state: _CheckState.error,
            badge: AppStrings.t('BLOCKED', 'ถูกบล็อก', 'DISEKAT'),
            detail: AppStrings.t(
              'Location permission permanently denied. Enable it in App Settings.',
              'สิทธิ์ GPS ถูกปิดถาวร กรุณาเปิดในตั้งค่าแอปของเครื่อง',
              'Kebenaran lokasi ditolak kekal. Aktifkan di Tetapan Aplikasi.',
            ),
          ),
          canRequest: false,
          openSettings: true,
        );
      }
      return (
        result: _CheckItemResult(
          state: _CheckState.warn,
          badge: AppStrings.t(
            'PERMISSION NEEDED',
            'รออนุญาต',
            'PERLU KEBENARAN',
          ),
          detail: AppStrings.t(
            'Tap Allow GPS below to grant location access.',
            'แตะ "อนุญาต GPS" ด้านล่างเพื่อให้แอปอ่านพิกัดได้',
            'Ketik Benarkan GPS di bawah untuk akses lokasi.',
          ),
        ),
        canRequest: true,
        openSettings: false,
      );
    } catch (_) {
      return (
        result: _CheckItemResult(
          state: _CheckState.warn,
          badge: AppStrings.t('UNAVAILABLE', 'ไม่พร้อมใช้', 'TIADA'),
          detail: AppStrings.t(
            'Location plugin is not available on this platform.',
            'ไม่สามารถตรวจสอบ GPS บนอุปกรณ์นี้ได้',
            'Plugin lokasi tidak tersedia pada peranti ini.',
          ),
        ),
        canRequest: false,
        openSettings: false,
      );
    }
  }

  Future<({_CheckItemResult result, bool openSettings})> _checkCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        return (
          result: _CheckItemResult(
            state: _CheckState.warn,
            badge: AppStrings.t('NO CAMERA', 'ไม่พบกล้อง', 'TIADA KAMERA'),
            detail: AppStrings.t(
              'No camera detected or permission blocked in OS settings.',
              'ไม่พบกล้องในเครื่อง หรือสิทธิ์กล้องถูกปิดไว้',
              'Tiada kamera dikesan atau kebenaran disekat.',
            ),
          ),
          openSettings: true,
        );
      }
      return (
        result: _CheckItemResult(
          state: _CheckState.ok,
          badge: AppStrings.t(
            'READY (${cams.length})',
            'พร้อม (${cams.length} ตัว)',
            'SEDIA (${cams.length})',
          ),
          detail: AppStrings.t(
            'Camera hardware ready for attendance & work photos.',
            'กล้องพร้อมสำหรับถ่ายรูปตอกบัตรและรูปหน้างาน',
            'Kamera sedia untuk foto kehadiran & kerja.',
          ),
        ),
        openSettings: false,
      );
    } catch (_) {
      return (
        result: _CheckItemResult(
          state: _CheckState.warn,
          badge: AppStrings.t('UNAVAILABLE', 'ไม่พร้อมใช้', 'TIADA'),
          detail: AppStrings.t(
            'Camera unavailable or permission not granted yet.',
            'กล้องยังไม่พร้อม หรือยังไม่ได้รับอนุญาตสิทธิ์กล้อง',
            'Kamera tidak tersedia atau belum dibenarkan.',
          ),
        ),
        openSettings: false,
      );
    }
  }

  Future<void> _requestGpsPermission() async {
    if (AppPreferencesService.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    try {
      await Geolocator.requestPermission();
    } catch (_) {}
    if (mounted) {
      await _runChecks();
    }
  }

  Future<void> _openAppSettings() async {
    if (AppPreferencesService.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  Color _stateColor(_CheckState state) => switch (state) {
    _CheckState.ok => AppColors.success,
    _CheckState.warn => AppColors.warning,
    _CheckState.error => AppColors.error,
    _CheckState.checking => AppColors.secondary,
  };

  Widget _checkCard({
    required IconData icon,
    required String title,
    required _CheckItemResult item,
  }) {
    final badgeColor = _stateColor(item.state);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: badgeColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        item.badge,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.detail,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allOk =
        _server.state == _CheckState.ok &&
        _gps.state == _CheckState.ok &&
        _camera.state == _CheckState.ok;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neutral,
        iconTheme: IconThemeData(color: AppColors.neutral),
        title: Text(
          AppStrings.t(
            'Device & Connection Check',
            'ตรวจกล้อง GPS และเซิร์ฟเวอร์',
            'Semak Peranti & Sambungan',
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.t('Re-check', 'ตรวจใหม่', 'Semak semula'),
            onPressed: _running ? null : _runChecks,
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
                  AmbientPanel(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(
                          _running
                              ? Icons.sync_rounded
                              : allOk
                              ? Icons.verified_user_rounded
                              : Icons.health_and_safety_outlined,
                          size: 30,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _running
                                    ? AppStrings.t(
                                        'RUNNING DIAGNOSTICS...',
                                        'กำลังตรวจสอบความพร้อม...',
                                        'MENJALANKAN SEMAKAN...',
                                      )
                                    : allOk
                                    ? AppStrings.t(
                                        'ALL SYSTEMS READY',
                                        'พร้อมลงเวลาและส่งงาน',
                                        'SEMUA SISTEM SEDIA',
                                      )
                                    : AppStrings.t(
                                        'CHECK ITEMS BELOW',
                                        'ตรวจสอบรายการด้านล่าง',
                                        'SEMAK ITEM DI BAWAH',
                                      ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                !_running && _lastCheckedAt != null
                                    ? AppStrings.t(
                                        'Last checked · ${_lastCheckedAt!.hour.toString().padLeft(2, '0')}:${_lastCheckedAt!.minute.toString().padLeft(2, '0')}:${_lastCheckedAt!.second.toString().padLeft(2, '0')}',
                                        'ตรวจล่าสุด · ${_lastCheckedAt!.hour.toString().padLeft(2, '0')}:${_lastCheckedAt!.minute.toString().padLeft(2, '0')}:${_lastCheckedAt!.second.toString().padLeft(2, '0')}',
                                        'Semakan terakhir · ${_lastCheckedAt!.hour.toString().padLeft(2, '0')}:${_lastCheckedAt!.minute.toString().padLeft(2, '0')}:${_lastCheckedAt!.second.toString().padLeft(2, '0')}',
                                      )
                                    : AppStrings.t(
                                        'Quick check for EMS API, GPS and Camera permissions.',
                                        'เช็กการเชื่อมต่อเซิร์ฟเวอร์ สิทธิ์ GPS และกล้องหน้างาน',
                                        'Semakan pantas untuk API EMS, GPS dan Kamera.',
                                      ),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _checkCard(
                    icon: Icons.dns_outlined,
                    title: AppStrings.t(
                      'EMS Server',
                      'เซิร์ฟเวอร์ EMS',
                      'Pelayan EMS',
                    ),
                    item: _server,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _checkCard(
                    icon: Icons.location_on_outlined,
                    title: AppStrings.t(
                      'Location (GPS)',
                      'พิกัดตำแหน่ง (GPS)',
                      'Lokasi (GPS)',
                    ),
                    item: _gps,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _checkCard(
                    icon: Icons.camera_alt_outlined,
                    title: AppStrings.t('Camera', 'กล้องถ่ายรูป', 'Kamera'),
                    item: _camera,
                  ),
                  if (_canRequestGps || _needsAppSettings) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (_canRequestGps)
                          OutlinedButton.icon(
                            onPressed: _requestGpsPermission,
                            icon: const Icon(Icons.my_location_rounded, size: 18),
                            label: Text(
                              AppStrings.t(
                                'Allow GPS',
                                'อนุญาต GPS',
                                'Benarkan GPS',
                              ),
                            ),
                          ),
                        if (_needsAppSettings)
                          OutlinedButton.icon(
                            onPressed: _openAppSettings,
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            label: Text(
                              AppStrings.t(
                                'Open App Settings',
                                'เปิดตั้งค่าแอป',
                                'Buka Tetapan Aplikasi',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    key: const Key('device-check-recheck-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neutral,
                      foregroundColor: AppColors.onNeutral,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: _running
                        ? null
                        : () {
                            if (AppPreferencesService.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            _runChecks();
                          },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      AppStrings.t(
                        'Re-check Now',
                        'ตรวจสอบอีกครั้ง',
                        'Semak Sekarang',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
}
