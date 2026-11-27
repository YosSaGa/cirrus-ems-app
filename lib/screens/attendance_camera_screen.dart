import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/captured_photo.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/status_banner.dart';

/// Self-contained camera capture screen. Returns one photo via Navigator.pop.
enum _Phase {
  initializing,
  permissionDenied,
  unavailable,
  ready,
  capturing,
  preview,
  failure,
}

class AttendanceCameraScreen extends StatefulWidget {
  const AttendanceCameraScreen({super.key});

  @override
  State<AttendanceCameraScreen> createState() => _AttendanceCameraScreenState();
}

class _AttendanceCameraScreenState extends State<AttendanceCameraScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.initializing;
  String? _errorMessage;

  CameraController? _controller;
  CapturedPhoto? _preview;

  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;

  bool get _hasMultipleCameras => _cameras.length > 1;

  /// Guards against concurrent camera-switch operations.
  bool _switchingCamera = false;

  /// Prevents overlapping camera initialization requests.
  int _cameraRequestId = 0;

  /// Tracks whether the app is currently active.
  bool _appIsResumed = true;

  /// Serializes camera disposal operations.
  Future<void> _cameraDisposal = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  /// Releases camera on background, re-opens the same camera on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appIsResumed = false;

      // Invalidate any camera initialization currently in progress.
      _cameraRequestId++;

      _disposeController();

      if (mounted && (_phase == _Phase.ready || _phase == _Phase.capturing)) {
        setState(() {
          _phase = _Phase.initializing;
        });
      }

      return;
    }

    if (state == AppLifecycleState.resumed) {
      _appIsResumed = true;

      if (_cameras.isNotEmpty &&
          _controller == null &&
          (_phase == _Phase.ready ||
              _phase == _Phase.initializing ||
              _phase == _Phase.failure)) {
        _openController(_selectedCameraIndex);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _appIsResumed = false;
    _cameraRequestId++;

    _disposeController();

    super.dispose();
  }

  Future<void> _disposeController() {
    final controller = _controller;
    _controller = null;

    if (controller == null) {
      return _cameraDisposal;
    }

    _cameraDisposal = _cameraDisposal.then((_) async {
      try {
        await controller.dispose();
      } catch (_) {
        // Continue lifecycle cleanup even if disposal fails.
      }
    });

    return _cameraDisposal;
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _phase = _Phase.initializing;
      _errorMessage = null;
    });

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.unavailable;
        _errorMessage = 'Could not detect any camera on this device.';
      });
      return;
    }

    if (cameras.isEmpty) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.unavailable;
        _errorMessage = 'No camera is available on this device.';
      });
      return;
    }

    _cameras = cameras;

    // Prefer front camera; fall back to first available.
    var frontIndex = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (frontIndex == -1) frontIndex = 0;

    await _openController(frontIndex);
  }

  Future<void> _openController(int index) async {
    if (!_appIsResumed || !mounted) return;
    if (index < 0 || index >= _cameras.length) return;

    final requestId = ++_cameraRequestId;

    // Wait until previous camera sessions have been released.
    await _cameraDisposal;

    if (!mounted || !_appIsResumed || requestId != _cameraRequestId) {
      return;
    }

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
    } catch (e) {
      await controller.dispose();

      if (!mounted || !_appIsResumed || requestId != _cameraRequestId) {
        return;
      }

      final code = e is CameraException ? e.code : null;

      final isPermissionIssue =
          code == 'CameraAccessDenied' ||
          code == 'CameraAccessDeniedWithoutPrompt' ||
          code == 'CameraAccessRestricted' ||
          code == 'cameraPermission';

      setState(() {
        _phase = isPermissionIssue ? _Phase.permissionDenied : _Phase.failure;

        _errorMessage = isPermissionIssue
            ? 'Camera access was denied. Please allow camera access and '
                  'try again.'
            : 'The camera could not be started '
                  '(${e is CameraException ? e.description ?? e.code : e}).';
      });

      return;
    }

    // Discard an initialization that became outdated.
    if (!mounted || !_appIsResumed || requestId != _cameraRequestId) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _selectedCameraIndex = index;
      _phase = _Phase.ready;
      _errorMessage = null;
    });
  }

  Future<void> _switchCamera() async {
    if (_switchingCamera || !_hasMultipleCameras || _phase != _Phase.ready) {
      return;
    }

    _switchingCamera = true;
    setState(() => _phase = _Phase.initializing);

    await _disposeController();

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    try {
      await _openController(nextIndex);
    } finally {
      _switchingCamera = false;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_phase != _Phase.ready) return;

    setState(() => _phase = _Phase.capturing);

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';
      final extension = mimeType == 'image/png' ? 'png' : 'jpg';

      if (!mounted) return;
      setState(() {
        _preview = CapturedPhoto(
          bytes: bytes,
          fileName:
              'attendance_${DateTime.now().millisecondsSinceEpoch}.$extension',
          mimeType: mimeType,
        );
        _phase = _Phase.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failure;
        _errorMessage = 'Could not capture the photo. Please try again.';
      });
    }
  }

  void _retake() {
    setState(() {
      _preview = null;
      _phase = _Phase.ready;
    });
  }

  void _confirm() {
    final preview = _preview;
    if (preview == null) return;
    Navigator.of(context).pop(preview);
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  static const Color _cameraBg = Color(0xFF0A141E);

  @override
  Widget build(BuildContext context) {
    final isPreview = _phase == _Phase.preview;
    return Scaffold(
      backgroundColor: _cameraBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildPhaseBody(context)),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Row(
                children: [
                  _CloseButton(onPressed: _cancel),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          isPreview
                              ? AppStrings.t(
                                  'Review Photo',
                                  'ตรวจสอบรูปภาพ',
                                  'Semak Foto',
                                )
                              : AppStrings.t(
                                  'Attendance Photo',
                                  'ถ่ายรูปยืนยันตัวตน',
                                  'Foto Kehadiran',
                                ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isPreview && _hasMultipleCameras && _phase == _Phase.ready)
                    _SwitchCameraButton(
                      busy: _switchingCamera,
                      onPressed: _switchCamera,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseBody(BuildContext context) {
    switch (_phase) {
      case _Phase.initializing:
        return _CenteredMessage(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.secondary),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Preparing camera...',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        );

      case _Phase.permissionDenied:
        return _CenteredMessage(
          child: _MessagePanel(
            title: 'Camera Permission Needed',
            message:
                _errorMessage ??
                'Camera access was denied. Please allow camera access in '
                    'your device settings and try again.',
            primaryLabel: 'Try Again',
            onPrimary: _initializeCamera,
            secondaryLabel: 'Cancel',
            onSecondary: _cancel,
          ),
        );

      case _Phase.unavailable:
        return _CenteredMessage(
          child: _MessagePanel(
            title: 'Camera Unavailable',
            message:
                _errorMessage ?? 'No usable camera was found on this device.',
            primaryLabel: 'Cancel',
            onPrimary: _cancel,
          ),
        );

      case _Phase.failure:
        return _CenteredMessage(
          child: _MessagePanel(
            title: 'Capture Failed',
            message: _errorMessage ?? 'Something went wrong with the camera.',
            primaryLabel: 'Try Again',
            onPrimary: _initializeCamera,
            secondaryLabel: 'Cancel',
            onSecondary: _cancel,
          ),
        );

      case _Phase.ready:
      case _Phase.capturing:
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          return _CenteredMessage(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CameraPreview(controller),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      _cameraBg.withValues(alpha: 0.88),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.t(
                        'Position your face clearly in frame',
                        'จัดใบหน้าให้อยู่ในกรอบชัดเจนก่อนถ่าย',
                        'Pastikan wajah jelas dalam bingkai',
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ShutterButton(
                      busy: _phase == _Phase.capturing,
                      onPressed: _phase == _Phase.ready
                          ? () {
                              HapticFeedback.mediumImpact();
                              _capture();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case _Phase.preview:
        final preview = _preview;
        if (preview == null) {
          return _CenteredMessage(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        }
        return Column(
          children: [
            const SizedBox(height: 60),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Image.memory(preview.bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.42),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _retake();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 19),
                        label: Text(
                          AppStrings.t('Retake', 'ถ่ายใหม่', 'Ambil Semula'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: _cameraBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _confirm();
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          AppStrings.t('Use Photo', 'ใช้รูปนี้', 'Guna Foto'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: child,
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusBanner(
          variant: StatusVariant.error,
          title: title,
          message: message,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryCtaButton(label: primaryLabel, onPressed: onPrimary),
        if (secondaryLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          PrimaryActionButton(label: secondaryLabel!, onPressed: onSecondary),
        ],
      ],
    );
  }
}

class _SwitchCameraButton extends StatelessWidget {
  const _SwitchCameraButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        icon: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cameraswitch_outlined, color: Colors.white),
        tooltip: 'Switch camera',
        onPressed: busy ? null : onPressed,
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        tooltip: 'Cancel',
        onPressed: onPressed,
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Capture photo',
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppColors.secondary, width: 4),
          ),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: AppColors.neutral,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
