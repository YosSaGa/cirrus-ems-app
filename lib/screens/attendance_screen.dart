import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_strings.dart';
import '../models/captured_photo.dart';
import '../services/app_preferences_service.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/local_photo_store.dart';
import '../services/location_service.dart';
import '../services/technician_service.dart';
import '../services/work_timer_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/session_transition.dart';
import '../widgets/detail_row.dart';
import '../widgets/ambient_panel.dart';
import '../widgets/job_completed_dialog.dart';
import '../widgets/live_clock.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/status_banner.dart';
import '../widgets/status_chip.dart';
import '../widgets/technician_attendance_section.dart';
import '../widgets/time_action_button.dart';
import 'attendance_camera_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'technician_report_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _WindowInfo {
  final String label;
  final String kind;
  final IconData icon;
  const _WindowInfo(this.label, this.kind, this.icon);
}

const Map<String, _WindowInfo> _windowDisplayInfo = {
  'morning_in': _WindowInfo('Morning In', 'in', Icons.wb_sunny_outlined),
  'lunch_out': _WindowInfo('Lunch Out', 'lunch', Icons.restaurant),
  'afternoon_in': _WindowInfo('Afternoon In', 'in', Icons.wb_twilight),
  'leave': _WindowInfo('Leave', 'out', Icons.logout),
};

const List<String> _windowStepOrder = [
  'morning_in',
  'lunch_out',
  'afternoon_in',
  'leave',
];

enum _AccountMenuAction { profile, signOut }

class _AttendanceScreenState extends State<AttendanceScreen>
    with WidgetsBindingObserver {
  bool _loading = true;

  Map<String, dynamic>? _status;
  String? _statusError;

  // claude_prompt.txt (v172 -- Attendance Progress Status-Based Segment
  // Colors): the existing Attendance Status API's `latestEvent` is a
  // single, most-recent-overall scan (not even guaranteed to be today's,
  // per `_mobileTodaysActivity`'s own `isLatestEventToday` guard above) --
  // it cannot tell "Morning In and Afternoon In both recorded today, Lunch
  // Out skipped" apart from "only Afternoon In recorded", which Required
  // Behavior #5 explicitly requires distinguishing. The one existing,
  // already-integrated source that actually lists every counted scan for
  // a given work date is `AttendanceService.getMyScans()` (the v140 My
  // Scans API, already used by `history_screen.dart` the same way) --
  // reused here read-only, with no backend change, to build the set of
  // window codes actually completed today.
  Set<String> _completedWindowCodes = {};

  PendingAttendanceRequestLookup? _pendingLookup;
  String? _pendingError;

  bool _actionInProgress = false;
  String? _actionError;

  bool _navigatingToLogin = false;

  String? _userName;
  bool _isTechnician = false;
  TechnicianDashboardData? _techData;
  TechnicianJob? _selectedTechJob;
  Timer? _techPollTimer;
  bool _techPollingInFlight = false;
  Timer? _attendancePollTimer;
  bool _attendancePollingInFlight = false;
  bool _reportScreenOpen = false;
  Set<String>? _knownTechJobIds;
  String? _promptedPendingReportSessionId;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  // claude_prompt.txt (v171 §3 "Web may retain its existing in-memory
  // behavior ... do not implement IndexedDB"): on every OTHER platform,
  // a captured photo is persisted durably via `LocalPhotoStore` (an
  // app-private file, path recorded in the pending request -- survives
  // an app restart). Web has no comparable durable, app-private file
  // store (`path_provider` has no web implementation), so this one field
  // is the sole remaining in-memory fallback, used ONLY when `kIsWeb` --
  // a direct descendant of v161's original `_pendingUploadPhoto`, now
  // narrowed to exactly the one platform that still needs it.
  CapturedPhoto? _webInMemoryPhoto;

  // claude_prompt.txt (v161 §7 "show upload progress / submission
  // progress separately where practical"): a short label shown next to
  // the Check-In action while `_actionInProgress` is true, naming which
  // of the three distinct steps (camera / upload / submit) is currently
  // running. `_actionInProgress` itself continues to gate duplicate taps
  // exactly as it always has.
  String? _checkInStageLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitial();
    _loadUserName();
  }

  @override
  void dispose() {
    _techPollTimer?.cancel();
    _attendancePollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isWidgetTest) {
        _ensureAttendancePolling();
        _pollAttendanceStatusSilently();
      }
      if (_isTechnician && !TechnicianService.isUsingMockOverride) {
        _ensureTechnicianPolling();
        _pollTechnicianJobsSilently();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _attendancePollTimer?.cancel();
      _attendancePollTimer = null;
      _techPollTimer?.cancel();
      _techPollTimer = null;
    }
  }

  void _ensureAttendancePolling() {
    if (_isWidgetTest) return;
    _attendancePollTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollAttendanceStatusSilently(),
    );
  }

  Future<void> _pollAttendanceStatusSilently() async {
    if (!mounted ||
        _isWidgetTest ||
        _attendancePollingInFlight ||
        _actionInProgress ||
        _loading ||
        _reportScreenOpen ||
        _navigatingToLogin) {
      return;
    }
    _attendancePollingInFlight = true;
    try {
      final status = await AttendanceService.getAttendanceStatus();
      if (!mounted || _navigatingToLogin) return;
      final completedWindowCodes = await _fetchCompletedWindowCodes(
        status['currentWorkDate']?.toString(),
      );
      if (_techData != null) {
        completedWindowCodes.addAll(_techData!.completedWindows);
      }
      if (!mounted || _navigatingToLogin) return;
      setState(() {
        _status = status;
        _statusError = null;
        _completedWindowCodes = completedWindowCodes;
      });
    } on AttendanceApiException catch (e) {
      _redirectIfAuthFailure(e);
    } catch (_) {
      // Silent background poll — ignore transient network blips
    } finally {
      _attendancePollingInFlight = false;
    }
  }

  void _ensureTechnicianPolling() {
    if (!_isTechnician || TechnicianService.isUsingMockOverride) return;
    _techPollTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollTechnicianJobsSilently(),
    );
  }

  Future<void> _pollTechnicianJobsSilently() async {
    if (!mounted ||
        !_isTechnician ||
        _techPollingInFlight ||
        _reportScreenOpen ||
        _actionInProgress ||
        _loading) {
      return;
    }
    _techPollingInFlight = true;
    try {
      final fresh = await TechnicianService.getMyJobs();
      if (!mounted) return;

      final prevIds = _knownTechJobIds;
      final freshIds = fresh.jobs.map((j) => j.id).toSet();
      final newJobs = prevIds == null
          ? const <TechnicianJob>[]
          : fresh.jobs.where((j) => !prevIds.contains(j.id)).toList();

      setState(() {
        _techData = fresh;
        _knownTechJobIds = freshIds;
        if (_selectedTechJob != null &&
            !fresh.jobs.any(
              (j) => j.id == _selectedTechJob!.id && j.isSelectableForCheckIn,
            )) {
          _selectedTechJob = null;
        }
        if (fresh.completedWindows.isNotEmpty) {
          _completedWindowCodes = {
            ..._completedWindowCodes,
            ...fresh.completedWindows,
          };
        }
      });

      unawaited(
        WorkTimerNotificationService.syncForActiveSession(fresh.activeSession),
      );

      if (fresh.pendingReportSession != null && fresh.activeSession == null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybePromptPendingReport(fresh),
        );
      }

      if (newJobs.isNotEmpty &&
          mounted &&
          AppPreferencesService.jobAlertsEnabled) {
        if (AppPreferencesService.hapticsEnabled) {
          HapticFeedback.heavyImpact();
        }
        final primary = newJobs.firstWhere(
          (j) => j.isMine,
          orElse: () => newJobs.first,
        );
        final titleSuffix = primary.title.isNotEmpty
            ? ' · ${primary.title}'
            : '';
        final scanSuffix = !_hasScannedAttendanceToday
            ? AppStrings.t(
                ' · Please scan attendance first',
                ' · อย่าลืมไปสแกนเข้างานด้วย',
                ' · Sila imbas kehadiran dahulu',
              )
            : '';
        final msg = newJobs.length == 1
            ? AppStrings.t(
                'New Job Code: ${primary.jobCode}$titleSuffix$scanSuffix',
                'มี Job Code ใหม่เข้า: ${primary.jobCode}$titleSuffix$scanSuffix',
                'Kod Kerja baharu: ${primary.jobCode}$titleSuffix$scanSuffix',
              )
            : AppStrings.t(
                '${newJobs.length} new Job Codes added (latest: ${primary.jobCode})$scanSuffix',
                'มี Job Code ใหม่เข้า ${newJobs.length} งาน (ล่าสุด: ${primary.jobCode})$scanSuffix',
                '${newJobs.length} Kod Kerja baharu ditambah (${primary.jobCode})$scanSuffix',
              );
        final alertTitle = newJobs.length == 1
            ? AppStrings.t(
                'New Job: ${primary.jobCode}',
                'มีงานใหม่เข้า: ${primary.jobCode}',
                'Kerja Baharu: ${primary.jobCode}',
              )
            : AppStrings.t(
                '${newJobs.length} New Jobs Assigned',
                'มีงานใหม่เข้า ${newJobs.length} งาน',
                '${newJobs.length} Kerja Baharu',
              );
        final alertParts = <String>[
          if (primary.title.isNotEmpty) primary.title,
          if (primary.vesselName != null && primary.vesselName!.isNotEmpty)
            primary.vesselName!,
          if (!_hasScannedAttendanceToday)
            AppStrings.t(
              'Please scan attendance first',
              'อย่าลืมไปสแกนเข้างานด้วย',
              'Sila imbas kehadiran dahulu',
            ),
        ];
        unawaited(
          WorkTimerNotificationService.showNewJobAlert(
            title: alertTitle,
            body: alertParts.isEmpty ? msg : alertParts.join(' · '),
            vibrate: AppPreferencesService.hapticsEnabled,
          ),
        );
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.neutral,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: TextStyle(
                      color: AppColors.onNeutral,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      // Silent background poll — ignore transient network blips
    } finally {
      _techPollingInFlight = false;
    }
  }

  Future<void> _loadUserName() async {
    final user = await AuthService.getSavedUser();
    if (!mounted) return;
    final name = user?['name']?.toString();
    if (name != null && name.isNotEmpty) {
      setState(() => _userName = name);
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _actionError = null;
    });

    Map<String, dynamic>? status;
    PendingAttendanceRequestLookup? pending;
    String? statusError;
    String? pendingError;
    TechnicianDashboardData? techData;
    String? techError;

    final isTechnician = await AuthService.isTechnician();

    Future<void> loadStatus() async {
      try {
        status = await AttendanceService.getAttendanceStatus();
      } on AttendanceApiException catch (e) {
        if (_redirectIfAuthFailure(e)) return;
        statusError = _messageForApiException(e);
      } catch (e) {
        statusError = _genericErrorMessage(e);
      }
    }

    Future<void> loadPending() async {
      try {
        pending = await AttendanceService.getPendingRequestForCurrentUser();
      } catch (e) {
        pendingError = _genericErrorMessage(e);
      }
    }

    Future<void> loadTechnician() async {
      if (!isTechnician) return;
      try {
        techData = await TechnicianService.getMyJobs();
      } catch (e) {
        techError = _genericErrorMessage(e);
      }
    }

    await Future.wait([loadStatus(), loadPending(), loadTechnician()]);

    final completedWindowCodes = await _fetchCompletedWindowCodes(
      status?['currentWorkDate']?.toString(),
    );
    if (techData != null) {
      completedWindowCodes.addAll(techData!.completedWindows);
    }

    if (!mounted || _navigatingToLogin) return;

    TechnicianJob? nextSelected = _selectedTechJob;
    if (techData != null) {
      if (nextSelected != null &&
          !techData!.jobs.any(
            (j) => j.id == nextSelected!.id && j.isSelectableForCheckIn,
          )) {
        nextSelected = null;
      }
    }

    setState(() {
      _isTechnician = isTechnician;
      _techData = techData;
      if (techData != null) {
        _knownTechJobIds = techData!.jobs.map((j) => j.id).toSet();
      }
      _selectedTechJob = nextSelected;
      _status = status;
      _statusError = statusError;
      _pendingLookup = pending;
      _pendingError = pendingError;
      if (techError != null && _actionError == null) {
        _actionError = techError;
      }
      _completedWindowCodes = completedWindowCodes;
      _loading = false;
    });
    _ensureAttendancePolling();
    _ensureTechnicianPolling();
    unawaited(
      WorkTimerNotificationService.syncForActiveSession(
        _isTechnician ? techData?.activeSession : null,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybePromptPendingReport(techData),
    );
  }

  Future<void> _maybePromptPendingReport(TechnicianDashboardData? data) async {
    if (!mounted || _navigatingToLogin) return;
    final pending = data?.pendingReportSession;
    if (pending == null || data?.activeSession != null) return;
    if (_promptedPendingReportSessionId == pending.id) return;
    _promptedPendingReportSessionId = pending.id;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('pending-report-startup-dialog'),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          icon: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_late_outlined,
              color: AppColors.warning,
              size: 26,
            ),
          ),
          title: Text(
            AppStrings.t(
              'Pending Work Report',
              'มีรายงานการทำงานค้างอยู่',
              'Laporan Kerja Tertunda',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.neutral,
            ),
          ),
          content: Text(
            () {
              final lateMin = pending.reportLateMinutes();
              final base = AppStrings.t(
                'You finished ${pending.jobCode} but have not submitted the work report yet. You must complete this report before using other parts of the app.',
                'คุณจบงาน ${pending.jobCode} แล้ว แต่ยังไม่ได้ส่งรายงานการทำงาน กรุณากรอกรายงานที่ค้างไว้ให้เสร็จก่อนใช้งานส่วนอื่น',
                'Anda telah menamatkan ${pending.jobCode} tetapi belum menghantar laporan. Anda mesti melengkapkan laporan ini sebelum menggunakan bahagian lain.',
              );
              if (lateMin <= 0) return base;
              final lateNote = AppStrings.t(
                '\n\nOverdue by $lateMin min (past 07:00 deadline).',
                '\n\nส่งรายงานเกินกำหนด 07:00 น. แล้ว $lateMin นาที',
                '\n\nLewat $lateMin minit (melepasi had 07:00).',
              );
              return '$base$lateNote';
            }(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('pending-report-startup-ok-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neutral,
                  foregroundColor: AppColors.onNeutral,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(
                  AppStrings.t('OK', 'ตกลง', 'OK'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _openTechnicianReport(pending);
    }
  }

  // claude_prompt.txt (v172 §Required Behavior #6/#7): "the UI must
  // reflect the actual attendance status returned by the existing
  // Attendance Status API" and "refreshing the screen ... must display
  // the same status as the backend" -- scoped to the SAME `workDate` the
  // Status API itself reports as current, so this never shows a stale or
  // mismatched day's completions. Never throws: any failure (including
  // auth) just yields an empty set, which safely renders every segment
  // grey rather than breaking the rest of the screen.
  Future<Set<String>> _fetchCompletedWindowCodes(String? workDate) async {
    if (workDate == null || workDate.isEmpty) return {};
    try {
      final date = DateTime.parse(workDate);
      final scans = await AttendanceService.getMyScans(from: date, to: date);
      return {
        for (final scan in scans)
          if (scan['windowCode'] != null) scan['windowCode'].toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadPendingOnly() async {
    try {
      final pending = await AttendanceService.getPendingRequestForCurrentUser();
      if (!mounted) return;
      setState(() {
        _pendingLookup = pending;
        _pendingError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingError = _genericErrorMessage(e);
      });
    }
  }

  Future<void> _refreshAfter(Map<String, dynamic> event) async {
    if (mounted) {
      setState(() {
        final patched = Map<String, dynamic>.from(
          _status ?? <String, dynamic>{},
        );
        patched['latestEvent'] = event;
        patched['latestEventCounted'] = event['counted'];
        patched['latestEventNotCountedReason'] = event['notCountedReason'];
        patched['latestEventFlag'] = event['flag'];
        _status = patched;
        _statusError = null;
        // claude_prompt.txt (v172 §Required Behavior #8 "Update the
        // indicator after a successful attendance submission using the
        // existing status-refresh mechanism"): optimistic patch, same as
        // `latestEvent` immediately above -- the authoritative re-fetch
        // below replaces this the moment it returns.
        final windowCode = event['windowCode']?.toString();
        if (windowCode != null && event['counted'] == true) {
          _completedWindowCodes = {..._completedWindowCodes, windowCode};
        }
      });
    }

    try {
      final status = await AttendanceService.getAttendanceStatus();
      final completedWindowCodes = await _fetchCompletedWindowCodes(
        status['currentWorkDate']?.toString(),
      );
      if (mounted) {
        setState(() {
          _status = status;
          _statusError = null;
          _completedWindowCodes = completedWindowCodes;
        });
      }
    } on AttendanceApiException catch (e) {
      if (_redirectIfAuthFailure(e)) return;
    } catch (_) {}

    await _loadPendingOnly();
  }

  // claude_prompt.txt (v171 -- Flutter Attendance Photo Persistence &
  // Retry Implementation, §1 "Mandatory User Flow" + §2 "Pending Request
  // Recovery"): the single handler for every normal attendance action
  // (Morning Check-In, Lunch Check-Out, Afternoon Check-In, Leave/
  // Check-Out) AND for resuming an already-in-progress one (the "Retry"
  // button, `_buildPrimaryAction`'s `valid` case, now calls this same
  // method rather than a separate standalone retry path) -- "submit for
  // the first time" and "resume an existing pending attempt" are the
  // exact same operation once a pending record exists, differing only in
  // which of steps 1-3 below are actually reached.
  //
  // §1's mandatory sequence, preserved exactly: tap -> open camera
  // immediately (unless resuming) -> capture -> upload -> persist
  // storageKey -> submit event with the SAME clientRequestId -> clear
  // only after confirmed success. `windowCode` is used only if this
  // genuinely starts a FRESH attempt (`AttendanceService.
  // beginOrResumeAttendanceAttempt` returns an existing record
  // unchanged, including its own already-stored windowCode, whenever one
  // is already pending -- this parameter is then simply ignored).
  Future<void> _checkIn({required String windowCode}) async {
    if (_actionInProgress) return;

    setState(() {
      _actionInProgress = true;
      _actionError = null;
      _checkInStageLabel = 'Preparing...';
    });

    try {
      final record = await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: windowCode,
      );
      final uploadRequestId = record['uploadRequestId'] as String?;
      var photoFilePath = record['photoFilePath'] as String?;
      final existingPayload = record['payload'] as Map?;
      var storageKey = existingPayload?['selfieStorageKey'] as String?;

      // claude_prompt.txt (v171 §2 "If a pending request already has a
      // storageKey: skip camera and upload; retry submitting the same
      // Attendance Event"): the entire capture/upload block below is
      // skipped outright whenever a storageKey is already persisted.
      if (storageKey == null) {
        CapturedPhoto? photo;

        // claude_prompt.txt (v171 §2 "If a pending request with a saved
        // photo exists but no storageKey: resume uploading that same
        // photo"): never recaptures when a usable photo is already
        // available -- durably on disk (non-Web) or still held in memory
        // (Web, this screen session only).
        if (!kIsWeb && photoFilePath != null) {
          photo = await LocalPhotoStore.read(photoFilePath);
          if (photo == null) {
            // claude_prompt.txt (v171 §3 "Handling corrupted or missing
            // local photo files"): the stored path no longer resolves to
            // a usable file -- clear the stale reference so the
            // record accurately reflects "no photo yet" before falling
            // through to recapture; `clientRequestId`/`uploadRequestId`
            // are left untouched (no content has been captured yet for
            // either value to conflict with).
            photoFilePath = null;
            await AttendanceService.recordCapturedPhotoPath(null);
          }
        } else if (kIsWeb) {
          photo = _webInMemoryPhoto;
        }

        if (photo == null) {
          if (!mounted) return;
          setState(() => _checkInStageLabel = 'Opening camera...');
          final captured = await Navigator.of(context).push<CapturedPhoto>(
            MaterialPageRoute(builder: (_) => const AttendanceCameraScreen()),
          );
          // claude_prompt.txt (v171 §5 "Camera cancelled before capture:
          // cancel the provisional operation; no upload and no
          // Attendance Event"): `captured == null` covers both an
          // explicit cancel and a back-navigation. Nothing durable has
          // happened yet on this path (no photo recorded, no
          // storageKey), so the provisional record created above is
          // cleared entirely rather than left behind to incorrectly look
          // like "a check-in is waiting to be sent" on the next visit.
          if (captured == null) {
            await AttendanceService.clearProvisionalAttemptIfNoProgress();
            return;
          }
          photo = captured;

          if (kIsWeb) {
            _webInMemoryPhoto = photo;
          } else {
            photoFilePath = await LocalPhotoStore.save(uploadRequestId!, photo);
            await AttendanceService.recordCapturedPhotoPath(photoFilePath);
          }
        }

        setState(() => _checkInStageLabel = 'Uploading photo...');

        try {
          storageKey = await AttendanceService.uploadAttendancePhoto(
            photo,
            uploadRequestId!,
          );
        } on AttendancePhotoUploadException catch (e) {
          // claude_prompt.txt (v171 §5 "Upload failure: retain the photo
          // and request metadata for retry"): the photo (file path or,
          // on Web, the in-memory reference) and the pending record
          // (with its clientRequestId/uploadRequestId) are already
          // durably in place from the steps above -- nothing further to
          // persist here, just surface the error and stop before any
          // Attendance Event is ever attempted.
          setState(() => _actionError = e.message);
          return;
        } on AttendanceApiException catch (e) {
          if (_redirectIfAuthFailure(e)) return;
          // claude_prompt.txt (v171 §5 "HTTP 409
          // ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD: retain pending state and
          // show a clear retry message. Do not create another upload
          // identity."): `_messageForApiException` already has a
          // dedicated case for this errorCode; retaining state is simply
          // "do nothing more" -- the pending record/photo are already in
          // place, and the SAME uploadRequestId is reused automatically
          // on the next tap since it is read back from the record above,
          // never regenerated.
          setState(() => _actionError = _messageForApiException(e));
          return;
        }

        // claude_prompt.txt (v171 §4 "After receiving storageKey, persist
        // it immediately before attempting Event submission"): and, on
        // Web, the in-memory photo is no longer needed for a retry of
        // THIS attempt from this point on (a later Event-submission
        // failure recovers via the persisted storageKey alone, never by
        // re-uploading) -- cleared the instant it is no longer the thing
        // being retried, so it can never be mistaken for a fresh photo on
        // some LATER, different attempt.
        await AttendanceService.recordUploadedStorageKey(storageKey);
        if (kIsWeb) _webInMemoryPhoto = null;
      }

      setState(() => _checkInStageLabel = 'Submitting attendance...');

      final location = await LocationService.captureCurrentLocation();
      await AttendanceService.mergeFreshLocationIntoPendingRequest(
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracy: location?.accuracy,
      );
      final result = await AttendanceService.retryPendingAttendanceEvent();
      await _handleSubmissionResult(result);
    } on AttendanceApiException catch (e) {
      if (_redirectIfAuthFailure(e)) return;
      setState(() => _actionError = _messageForApiException(e));
      // claude_prompt.txt (v171 §5): a failed upload or event submission
      // must retain the pending request so the UI offers "Retry" -- the
      // record in SharedPreferences is already retained by this point,
      // but `_pendingLookup` (what the UI actually renders from) is only
      // refreshed by reloading it.
      await _loadPendingOnly();
    } on MalformedPendingRequestException catch (_) {
      await _loadPendingOnly();
    } on StateError catch (_) {
      await _loadPendingOnly();
    } catch (e) {
      setState(() => _actionError = _genericErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _checkInStageLabel = null;
        });
      }
    }
  }

  Future<void> _discard() async {
    if (_actionInProgress) return;

    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });

    try {
      final outcome = await AttendanceService.discardMalformedPendingRequest();
      if (outcome == DiscardPendingRequestOutcome.busy) {
        setState(() {
          _actionError =
              'Another attendance action is already in progress. Please wait.';
        });
      }
      await _loadPendingOnly();
    } catch (e) {
      setState(() => _actionError = _genericErrorMessage(e));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _refreshStatusOnly() async {
    try {
      final status = await AttendanceService.getAttendanceStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _statusError = null;
        });
      }
    } on AttendanceApiException catch (e) {
      if (_redirectIfAuthFailure(e)) return;
    } catch (_) {}
  }

  Future<void> _confirmPendingCheckout(String workDate) async {
    if (_actionInProgress) return;

    setState(() {
      _actionInProgress = true;
      _actionError = null;
    });

    try {
      final result = await AttendanceService.resolvePendingCheckout(
        workDate: workDate,
      );

      switch (result.outcome) {
        case ResolvePendingCheckoutOutcome.resolved:
        case ResolvePendingCheckoutOutcome.replay:
          await _refreshStatusOnly();
          // claude_prompt.txt (v116 §3 / v117 §3): the Backend has
          // already confirmed success at this point -- a true local
          // cleanup failure is communicated explicitly, distinct from a
          // Backend failure, never silently discarded, and never phrased
          // as "no action needed" without saying cleanup itself is still
          // pending.
          if (result.cleanupFailed && mounted) {
            setState(() {
              _actionError =
                  'Your Leave checkout was confirmed successfully. A '
                  'local cleanup step remains pending on this device, '
                  'but no action is needed from you.';
            });
          }
          break;
        case ResolvePendingCheckoutOutcome.alreadyResolved:
          // claude_prompt.txt (v117 §3): handled entirely inside
          // AttendanceService.resolvePendingCheckout now -- this branch
          // only reacts to the already-performed outcome, it never calls
          // cleanup itself and never re-throws anything from doing so.
          await _refreshStatusOnly();
          if (result.cleanupFailed && mounted) {
            setState(() {
              _actionError =
                  'This Leave checkout has already been resolved. A '
                  'local cleanup step remains pending on this device, '
                  'but no action is needed from you.';
            });
          }
          break;
        case ResolvePendingCheckoutOutcome.busy:
          setState(() {
            _actionError = 'Another attendance action is already in progress. Please wait.';
          });
          break;
      }
    } on AttendanceApiException catch (e) {
      // claude_prompt.txt (v117 §3): APP_ATTENDANCE_PENDING_CHECKOUT_ALREADY_RESOLVED
      // is no longer thrown by AttendanceService.resolvePendingCheckout
      // at all -- it is converted into
      // ResolvePendingCheckoutOutcome.alreadyResolved above, with its own
      // cleanup already performed using the correctly-captured userId.
      // Every exception reaching this branch is therefore some OTHER
      // error code (or an authentication failure), handled exactly as
      // before.
      if (_redirectIfAuthFailure(e)) return;

      setState(() => _actionError = _messageForApiException(e));

      if (e.errorCode == 'APP_ATTENDANCE_NO_PENDING_CHECKOUT' ||
          e.errorCode == 'APP_ATTENDANCE_PENDING_CHECKOUT_WORKDATE_MISMATCH') {
        await _refreshStatusOnly();
      }
    } on MalformedPendingCheckoutRequestIdException catch (e) {
      // claude_prompt.txt (v116 §4): a stored, non-UUID request id for
      // this work date -- no HTTP request was sent (AttendanceService
      // never reaches the POST call for this case), and the malformed
      // value itself was neither overwritten nor deleted. Surfaced
      // explicitly rather than falling through to the generic branch
      // below, so this specific condition is named clearly.
      setState(() => _actionError = e.message);
    } catch (e) {
      setState(() => _actionError = _genericErrorMessage(e));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleSubmissionResult(
    AttendanceSubmissionResult result,
  ) async {
    switch (result.outcome) {
      case AttendanceSubmissionOutcome.created:
      case AttendanceSubmissionOutcome.replay:
        await _refreshAfter(result.event!);
        break;
      case AttendanceSubmissionOutcome.pendingRequestExists:
      case AttendanceSubmissionOutcome.malformedPendingRequestDetected:
        await _loadPendingOnly();
        break;
      case AttendanceSubmissionOutcome.busy:
        setState(() {
          _actionError =
              'Another attendance action is already in progress. Please wait.';
        });
        break;
    }
  }

  Future<void> _logout() async {
    bool hasPending = false;
    try {
      final pending = await AttendanceService.getPendingRequestForCurrentUser();
      hasPending = pending.state == PendingAttendanceRequestState.valid;
    } catch (_) {}
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        title: Text(
          AppStrings.t('Log out?', 'ออกจากระบบหรือไม่?', 'Log keluar?'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.neutral,
          ),
        ),
        content: Text(
          hasPending
              ? AppStrings.t(
                  'You have a pending check-in. Sign in to this account again to retry it.',
                  'คุณมีรายการลงเวลาที่รอส่ง กรุณาเข้าสู่บัญชีนี้อีกครั้งเพื่อส่งรายการ',
                  'Anda mempunyai daftar masuk tertunda. Log masuk semula ke akaun ini untuk mencuba lagi.',
                )
              : AppStrings.t(
                  'Are you sure you want to sign out of your account?',
                  'คุณต้องการออกจากระบบบัญชีนี้ใช่หรือไม่?',
                  'Adakah anda pasti mahu log keluar daripada akaun anda?',
                ),
          style: TextStyle(
            color: hasPending ? AppColors.error : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.t('Cancel', 'ยกเลิก', 'Batal')),
          ),
          FilledButton(
            key: const Key('confirm-logout-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.t('Log Out', 'ออกจากระบบ', 'Log Keluar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    TechnicianService.clearCachedDashboard();
    unawaited(WorkTimerNotificationService.cancel());
    await AuthService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      sessionTransition(context, const LoginScreen()),
      (route) => false,
    );
  }

  bool _redirectIfAuthFailure(AttendanceApiException error) {
    final isAuthFailure =
        error.errorCode == 'AUTHENTICATION_REQUIRED' ||
        (error.errorCode == null && error.statusCode == 401);
    if (!isAuthFailure) return false;

    if (!mounted || _navigatingToLogin) return true;
    _navigatingToLogin = true;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    return true;
  }

  String _messageForApiException(AttendanceApiException e) {
    switch (e.errorCode) {
      case 'VALIDATION_FAILED':
        return e.message;
      case 'PERMISSION_DENIED':
        return 'You do not have permission to perform this action.';
      case 'APP_ATTENDANCE_EMPLOYMENT_NOT_ELIGIBLE':
        return 'Your employment status does not allow attendance '
            'check-in. Contact your administrator if this is unexpected.';
      case 'APP_ATTENDANCE_EMPLOYEE_NOT_FOUND':
        return 'No employee record was found for your account. Contact '
            'your administrator.';
      case 'APP_ATTENDANCE_EMPLOYEE_CODE_MISSING':
        return 'Your account is not yet linked to a device user code. '
            'Contact your administrator.';
      case 'APP_ATTENDANCE_PENDING_CHECKOUT_ALREADY_RESOLVED':
        return 'This Leave checkout has already been resolved.';
      case 'APP_ATTENDANCE_NO_PENDING_CHECKOUT':
        return 'There is no Pending Checkout to confirm right now.';
      case 'APP_ATTENDANCE_PENDING_CHECKOUT_WORKDATE_MISMATCH':
        return 'The pending work date has changed. Please check the '
            'updated Pending Checkout below.';
      case 'APP_ATTENDANCE_CLIENT_REQUEST_ID_WORKDATE_MISMATCH':
        return 'This confirmation could not be matched to the correct '
            'work date. Please try again.';
      case 'APP_ATTENDANCE_INVALID_LEAVE_WINDOW_CONFIGURATION':
        return 'Pending Checkout cannot be processed because the Leave '
            'window configuration is invalid. Contact your administrator.';
      case 'APP_ATTENDANCE_LEAVE_WINDOW_MISSING_REFERENCE_TIME':
        return 'Pending Checkout cannot be processed because the Leave '
            'window has no configured reference time. Contact your '
            'administrator.';
      case 'INTERNAL_SERVER_ERROR':
        return 'A server error occurred. Please try again later.';
      // claude_prompt.txt (v171 §5 "HTTP 409
      // ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD: ... show a clear retry
      // message"): the Backend's v170 idempotency implementation's
      // "another worker currently owns this upload identity's lease"
      // signal -- surfaced here exactly like every other errorCode this
      // switch already translates, no new exception-handling machinery
      // needed.
      case 'ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD':
        return 'This attendance photo is still being processed from a '
            'previous attempt. Please wait a moment and try again.';
      default:
        return e.message.isNotEmpty
            ? e.message
            : 'Something went wrong (${e.statusCode}).';
    }
  }

  String _genericErrorMessage(Object e) => AppStrings.friendlyError(e);

  String _gpsWarningSuffix(CapturedLocation? location) {
    if (location != null) return '';
    return AppStrings.t(
      ' (GPS unavailable — check Location settings)',
      ' (จับพิกัด GPS ไม่ได้ — กรุณาเปิด Location)',
      ' (GPS tidak tersedia — semak tetapan Lokasi)',
    );
  }

  int? _positiveMinutes(dynamic value) {
    if (value is num && value > 0) return value.round();
    return null;
  }

  String _notCountedMessage(String reason) {
    switch (reason) {
      case 'duplicate_in_window':
        return 'Attendance for this time window has already been recorded.';
      case 'outside_window':
        return 'This submission is outside the allowed attendance window.';
      default:
        return reason;
    }
  }

  String _greeting() {
    final hour = DateTime.now().toUtc().add(const Duration(hours: 7)).hour;
    final name = _userName;
    final who = (name == null || name.isEmpty)
        ? ''
        : (AppStrings.isThai
              ? ' คุณ ${name.split(' ').first}'
              : ', ${name.split(' ').first}');
    if (hour < 12) {
      return AppStrings.isThai ? 'สวัสดีตอนเช้า$who' : 'Good morning$who';
    }
    if (hour < 17) {
      return AppStrings.isThai ? 'สวัสดีตอนบ่าย$who' : 'Good afternoon$who';
    }
    return AppStrings.isThai ? 'สวัสดีตอนเย็น$who' : 'Good evening$who';
  }

  String _formatDate(String? isoWorkDate) {
    if (isoWorkDate != null) {
      try {
        final date = DateTime.parse(isoWorkDate);
        return AppStrings.formatFullDate(date);
      } catch (_) {
        return isoWorkDate;
      }
    }
    final bangkokNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    return AppStrings.formatFullDate(bangkokNow);
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatScannedAt(String? raw) {
    if (raw == null) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final bangkok = parsed.toUtc().add(const Duration(hours: 7));
    final time =
        '${_twoDigits(bangkok.hour)}:${_twoDigits(bangkok.minute)}:${_twoDigits(bangkok.second)}';
    return '${AppStrings.formatShortDate(bangkok)} $time';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: isDesktop ? _desktopAppBar(context) : _mobileAppBar(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: isDesktop
                  ? _desktopLayout(context)
                  : _mobileLayout(context),
            ),
    );
  }

  AppBar _desktopAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.neutral,
      iconTheme: IconThemeData(color: AppColors.neutral),
      title: Text(
        AppStrings.t('Attendance', 'ลงเวลา'),
        style: TextStyle(color: AppColors.neutral, fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: AppStrings.t('Refresh', 'รีเฟรช'),
          onPressed: _loading ? null : _loadInitial,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: AppStrings.t('Profile', 'โปรไฟล์'),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          icon: const Icon(Icons.person_outline),
        ),
        IconButton(
          tooltip: AppStrings.t('Sign out', 'ออกจากระบบ'),
          onPressed: _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }

  AppBar _mobileAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.neutral),
      title: Text(
        AppStrings.t('Attendance', 'ลงเวลา'),
        style: TextStyle(
          color: AppColors.neutral,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: AppStrings.t('Refresh', 'รีเฟรช'),
          onPressed: _loading ? null : _loadInitial,
          icon: const Icon(Icons.refresh),
        ),
        PopupMenuButton<_AccountMenuAction>(
          tooltip: AppStrings.t('Account', 'บัญชี'),
          icon: Icon(Icons.person_outline, color: AppColors.neutral),
          color: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (action) {
            switch (action) {
              case _AccountMenuAction.profile:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                break;
              case _AccountMenuAction.signOut:
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _AccountMenuAction.profile,
              height: 48,
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: AppColors.neutral),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.t('Profile', 'โปรไฟล์'),
                    style: TextStyle(color: AppColors.neutral),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: _AccountMenuAction.signOut,
              height: 48,
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppColors.neutral),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.t('Sign out', 'ออกจากระบบ'),
                    style: TextStyle(color: AppColors.neutral),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mobileLayout(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _loadInitial,
      child: SingleChildScrollView(
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, appTabBottomPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _mobileHeroClockCard(context),
            const SizedBox(height: AppSpacing.lg),
            _mobileActionZone(context),
            const SizedBox(height: AppSpacing.lg),
            _mobileActivitySheet(context),
          ],
        ),
      ),
    );
  }

  /// Compact Deep Navy ambient hero card pairing greeting, status, and live clock.
  Widget _mobileHeroClockCard(BuildContext context) {
    final windowCode = _status?['currentWindowCode']?.toString();
    final windowInfo = windowCode == null
        ? null
        : _windowDisplayInfo[windowCode];
    final windowLabel = windowCode == null
        ? AppStrings.t('No active window', 'ไม่อยู่ในช่วงเวลาสแกน')
        : (windowInfo != null
              ? AppStrings.scanWindowLabel(windowInfo.label)
              : 'Unrecognized window ($windowCode)');
    final isOpen = windowInfo != null;

    return AmbientPanel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(_status?['currentWorkDate']?.toString()),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onNeutralMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTechnician)
                const TechnicianRoleBadge()
              else if (_status != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? AppColors.secondary.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isOpen
                          ? AppColors.secondary.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: isOpen
                            ? AppColors.secondary
                            : AppColors.onNeutralMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        windowLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOpen
                              ? AppColors.secondary
                              : AppColors.onNeutralMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LiveClock(
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                AppStrings.t('BANGKOK TIME', 'เวลาประเทศไทย'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onNeutralMuted,
                  letterSpacing: AppStrings.isThai ? 0 : 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasScannedAttendanceToday {
    if (_completedWindowCodes.isNotEmpty) return true;
    if (_techData != null && _techData!.completedWindows.isNotEmpty) {
      return true;
    }
    final workDate = _status?['currentWorkDate']?.toString();
    bool isTodayEvent(dynamic raw) {
      if (raw is! Map || raw.isEmpty) return false;
      if (workDate == null || workDate.isEmpty) return true;
      final evWorkDate = raw['workDate']?.toString();
      if (evWorkDate != null && evWorkDate.isNotEmpty) {
        return evWorkDate == workDate;
      }
      final scannedAt = raw['scannedAt']?.toString();
      if (scannedAt != null && scannedAt.isNotEmpty) {
        return scannedAt.startsWith(workDate);
      }
      return false;
    }

    return isTodayEvent(_status?['latestCountedEvent']) ||
        isTodayEvent(_status?['latestEvent']);
  }

  Future<void> _technicianCheckIn() async {
    final job = _selectedTechJob;
    if (_actionInProgress || job == null) return;
    final alreadyClockedIn = _hasScannedAttendanceToday;

    final windowCode =
        _techData?.nextWindowCode == 'afternoon_in'
            ? 'afternoon_in'
            : 'morning_in';

    setState(() {
      _actionInProgress = true;
      _actionError = null;
      _checkInStageLabel = AppStrings.t(
        'Opening camera...',
        'กำลังเปิดกล้อง...',
        'Membuka kamera...',
      );
    });

    try {
      final captured = await Navigator.of(context).push<CapturedPhoto>(
        MaterialPageRoute(builder: (_) => const AttendanceCameraScreen()),
      );
      if (captured == null || !mounted) return;

      setState(
        () => _checkInStageLabel = AppStrings.t(
          'Uploading photo...',
          'กำลังอัปโหลดรูปภาพ...',
          'Memuat naik foto...',
        ),
      );
      final uploadId = const Uuid().v4();
      final storageKey = await AttendanceService.uploadAttendancePhoto(
        captured,
        uploadId,
      );

      if (!mounted) return;
      setState(
        () => _checkInStageLabel = alreadyClockedIn
            ? AppStrings.t(
                'Recording GPS & starting job...',
                'กำลังบันทึกพิกัด GPS และเริ่มงาน...',
                'Merekod GPS & memulakan kerja...',
              )
            : AppStrings.t(
                'Recording GPS & check-in...',
                'กำลังบันทึกพิกัด GPS และเช็คอิน...',
                'Merekod GPS & daftar masuk...',
              ),
      );
      final location = await LocationService.captureCurrentLocation();

      await TechnicianService.checkIn(
        jobId: job.id,
        jobSource: job.jobSource,
        windowCode: windowCode,
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracy: location?.accuracy,
        photoStorageKey: storageKey,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            content: Text(
              alreadyClockedIn
                  ? '${AppStrings.t('Started job ${job.jobCode}', 'เริ่มงาน ${job.jobCode} เรียบร้อยแล้ว', 'Kerja ${job.jobCode} dimulakan')}${_gpsWarningSuffix(location)}'
                  : '${AppStrings.t('Checked in to ${job.jobCode}', 'เช็คอินงาน ${job.jobCode} เรียบร้อยแล้ว', 'Berjaya daftar masuk ke ${job.jobCode}')}${_gpsWarningSuffix(location)}',
            ),
          ),
        );
      await _loadInitial();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = _genericErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _checkInStageLabel = null;
        });
      }
    }
  }

  Future<void> _technicianCheckOut() async {
    final active = _techData?.activeSession;
    if (_actionInProgress || active == null) return;

    final autoWindow =
        _techData?.nextWindowCode == 'leave' ? 'leave' : 'lunch_out';
    final periodLabel = autoWindow == 'leave'
        ? AppStrings.t(
            'End of Day (Leave)',
            'ออกงานเย็น (Leave)',
            'Tamat Kerja (Pulang)',
          )
        : AppStrings.t(
            'Lunch Break Out',
            'พักเที่ยง (Lunch Out)',
            'Rehat Tengah Hari',
          );
    String selectedJobStatus = 'in_progress';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.t(
                          'Check Out · ${active.jobCode}',
                          'เช็คเอาท์ · ${active.jobCode}',
                          'Daftar Keluar · ${active.jobCode}',
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neutral,
                        ),
                      ),
                    ),
                    StatusChip(
                      label: periodLabel,
                      variant: ChipVariant.active,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.t(
                    'Job Progress',
                    'สถานะงาน',
                    'Status Kerja',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(
                        AppStrings.t('In Progress', 'กำลังทำต่อ', 'Sedang Berjalan'),
                      ),
                      selected: selectedJobStatus == 'in_progress',
                      onSelected: (_) =>
                          setSheetState(() => selectedJobStatus = 'in_progress'),
                    ),
                    ChoiceChip(
                      label: Text(
                        AppStrings.t('Completed', 'งานเสร็จแล้ว', 'Selesai'),
                      ),
                      selected: selectedJobStatus == 'completed',
                      onSelected: (_) =>
                          setSheetState(() => selectedJobStatus = 'completed'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neutral,
                    foregroundColor: AppColors.onNeutral,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(
                    AppStrings.t(
                      'Take Photo & Check Out',
                      'ถ่ายรูปและเช็คเอาท์',
                      'Ambil Foto & Daftar Keluar',
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _actionInProgress = true;
      _actionError = null;
      _checkInStageLabel = AppStrings.t(
        'Opening camera...',
        'กำลังเปิดกล้อง...',
        'Membuka kamera...',
      );
    });

    try {
      final captured = await Navigator.of(context).push<CapturedPhoto>(
        MaterialPageRoute(builder: (_) => const AttendanceCameraScreen()),
      );
      if (captured == null || !mounted) return;

      setState(
        () => _checkInStageLabel = AppStrings.t(
          'Uploading photo...',
          'กำลังอัปโหลดรูปภาพ...',
          'Memuat naik foto...',
        ),
      );
      final uploadId = const Uuid().v4();
      final storageKey = await AttendanceService.uploadAttendancePhoto(
        captured,
        uploadId,
      );

      if (!mounted) return;
      setState(
        () => _checkInStageLabel = AppStrings.t(
          'Recording GPS & check-out...',
          'กำลังบันทึกพิกัด GPS และเช็คเอาท์...',
          'Merekod GPS & daftar keluar...',
        ),
      );
      final location = await LocationService.captureCurrentLocation();

      final outRes = await TechnicianService.checkOut(
        sessionId: active.id,
        windowCode: autoWindow,
        jobStatus: selectedJobStatus,
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracy: location?.accuracy,
        photoStorageKey: storageKey,
      );

      if (!mounted) return;
      final outSessionMap = outRes['session'] as Map<String, dynamic>?;
      final completedSession = TechnicianWorkSession(
        id: active.id,
        jobId: active.jobId,
        jobSource: active.jobSource,
        jobCode: active.jobCode,
        jobTitle: active.jobTitle,
        status: 'completed',
        checkInAt: active.checkInAt,
        checkOutAt:
            outSessionMap?['checkOutAt']?.toString() ??
            DateTime.now().toIso8601String(),
        durationMinutes: outSessionMap?['durationMinutes'] is num
            ? (outSessionMap!['durationMinutes'] as num).toDouble()
            : active.durationMinutes,
        checkInLatitude: active.checkInLatitude,
        checkInLongitude: active.checkInLongitude,
        jobStatusAtCheckout: selectedJobStatus,
      );

      setState(() {
        _actionInProgress = false;
        _checkInStageLabel = null;
      });
      if (location == null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              content: Text(
                AppStrings.t(
                  'Checked out without GPS coordinates — please check Location settings.',
                  'เช็คเอาท์แล้วแต่จับพิกัด GPS ไม่ได้ — กรุณาเปิด Location',
                  'Daftar keluar tanpa GPS — sila semak tetapan Lokasi.',
                ),
              ),
            ),
          );
      }
      await _openTechnicianReport(completedSession);
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = _genericErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _checkInStageLabel = null;
        });
      }
    }
  }

  Future<void> _openTechnicianReport(TechnicianWorkSession session) async {
    if (_reportScreenOpen) return;
    _reportScreenOpen = true;
    bool? submitted;
    try {
      submitted = await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              TechnicianReportScreen(session: session, mandatory: true),
        ),
      );
    } finally {
      _reportScreenOpen = false;
    }
    if (!mounted) return;
    if (submitted == true) {
      setState(() => _selectedTechJob = null);
      final isJobCompleted =
          (session.jobStatusAtCheckout ?? '').trim().toLowerCase() ==
          'completed';
      if (isJobCompleted) {
        if (AppPreferencesService.hapticsEnabled) {
          unawaited(HapticFeedback.mediumImpact());
        }
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => JobCompletedDialog(jobCode: session.jobCode),
        );
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              content: Text(
                AppStrings.t(
                  'Work report submitted for ${session.jobCode}',
                  'ส่งรายงานงาน ${session.jobCode} เรียบร้อยแล้ว',
                  'Laporan kerja untuk ${session.jobCode} telah dihantar',
                ),
              ),
            ),
          );
      }
    } else {
      _promptedPendingReportSessionId = null;
    }
    if (!mounted) return;
    await _loadInitial();
  }

  Future<void> _technicianBreak() async {
    final active = _techData?.activeSession;
    if (_actionInProgress || active == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('confirm-technician-break-dialog'),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        title: Text(
          AppStrings.t('Take a Break?', 'ยืนยันพักเบรก?', 'Mula Rehat?'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.neutral,
          ),
        ),
        content: Text(
          AppStrings.t(
            'Pause work timer for ${active.jobCode}? No photo required.',
            'หยุดจับเวลางาน ${active.jobCode} ชั่วคราว (ไม่ต้องถ่ายรูป)',
            'Hentikan pemasa ${active.jobCode} sementara? Tiada foto diperlukan.',
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
                    AppStrings.t('Take a Break', 'พักเบรก', 'Rehat'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _actionInProgress = true;
      _actionError = null;
      _checkInStageLabel = AppStrings.t(
        'Recording break & GPS...',
        'กำลังบันทึกเวลาพักและ GPS...',
        'Merekod rehat & GPS...',
      );
    });

    try {
      final location = await LocationService.captureCurrentLocation();

      await TechnicianService.startBreak(
        sessionId: active.id,
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracy: location?.accuracy,
      );

      if (!mounted) return;
      unawaited(WorkTimerNotificationService.cancel());
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            content: Text(
              '${AppStrings.t('Break started for ${active.jobCode}', 'เริ่มพักเบรกงาน ${active.jobCode} แล้ว', 'Rehat dimulakan untuk ${active.jobCode}')}${_gpsWarningSuffix(location)}',
            ),
          ),
        );
      await _loadInitial();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = _genericErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _checkInStageLabel = null;
        });
      }
    }
  }

  Future<void> _technicianResumeFromBreak(
    TechnicianWorkSession breakSession,
  ) async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
      _actionError = null;
      _checkInStageLabel = AppStrings.t(
        'Opening camera...',
        'กำลังเปิดกล้อง...',
        'Membuka kamera...',
      );
    });

    try {
      final captured = await Navigator.of(context).push<CapturedPhoto>(
        MaterialPageRoute(builder: (_) => const AttendanceCameraScreen()),
      );
      if (captured == null || !mounted) return;

      setState(
        () => _checkInStageLabel = AppStrings.t(
          'Uploading photo...',
          'กำลังอัปโหลดรูปภาพ...',
          'Memuat naik foto...',
        ),
      );
      final uploadId = const Uuid().v4();
      final storageKey = await AttendanceService.uploadAttendancePhoto(
        captured,
        uploadId,
      );

      if (!mounted) return;
      setState(
        () => _checkInStageLabel = AppStrings.t(
          'Resuming work & recording GPS...',
          'กำลังกลับเข้าทำงานและบันทึก GPS...',
          'Menyambung kerja & merekod GPS...',
        ),
      );
      final location = await LocationService.captureCurrentLocation();

      await TechnicianService.checkIn(
        jobId: breakSession.jobId,
        jobSource: breakSession.jobSource,
        windowCode: 'afternoon_in',
        latitude: location?.latitude,
        longitude: location?.longitude,
        accuracy: location?.accuracy,
        photoStorageKey: storageKey,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            content: Text(
              '${AppStrings.t('Resumed work on ${breakSession.jobCode}', 'กลับเข้าทำงาน ${breakSession.jobCode} เรียบร้อยแล้ว', 'Kerja disambung pada ${breakSession.jobCode}')}${_gpsWarningSuffix(location)}',
            ),
          ),
        );
      await _loadInitial();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = _genericErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _checkInStageLabel = null;
        });
      }
    }
  }

  Future<void> _technicianEndFromBreak(
    TechnicianWorkSession breakSession,
  ) async {
    if (_actionInProgress) return;
    String selectedJobStatus = 'in_progress';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.t(
                    'End Shift · ${breakSession.jobCode}',
                    'จบงานเลย · ${breakSession.jobCode}',
                    'Tamat Kerja · ${breakSession.jobCode}',
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.t(
                    'Choose job progress before writing your work report.',
                    'เลือกสถานะงานก่อนเข้าไปเขียนรายงานการทำงาน',
                    'Pilih status kerja sebelum menulis laporan.',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(
                        AppStrings.t('In Progress', 'กำลังทำต่อ', 'Sedang Berjalan'),
                      ),
                      selected: selectedJobStatus == 'in_progress',
                      onSelected: (_) =>
                          setSheetState(() => selectedJobStatus = 'in_progress'),
                    ),
                    ChoiceChip(
                      label: Text(
                        AppStrings.t('Completed', 'งานเสร็จแล้ว', 'Selesai'),
                      ),
                      selected: selectedJobStatus == 'completed',
                      onSelected: (_) =>
                          setSheetState(() => selectedJobStatus = 'completed'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neutral,
                    foregroundColor: AppColors.onNeutral,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 19),
                  label: Text(
                    AppStrings.t(
                      'Confirm & Write Report',
                      'ยืนยันจบงานและเขียนรายงาน',
                      'Sahkan & Tulis Laporan',
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      await TechnicianService.endFromBreak(
        sessionId: breakSession.id,
        jobStatus: selectedJobStatus,
      );
      if (!mounted) return;
      unawaited(WorkTimerNotificationService.cancel());
      setState(() => _actionInProgress = false);
      await _openTechnicianReport(breakSession);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = _genericErrorMessage(e);
        _actionInProgress = false;
      });
    }
  }

  /// Floating circular check-in centerpiece directly on the clean canvas.
  Widget _mobileActionZone(BuildContext context) {
    if (_isTechnician) {
      final currentWindowCode = _status?['currentWindowCode']?.toString();
      final currentWorkDate = _status?['currentWorkDate']?.toString();
      final windowInfo = currentWindowCode != null
          ? _windowDisplayInfo[currentWindowCode]
          : null;
      final latestCounted =
          _status?['latestCountedEvent'] as Map<String, dynamic>?;
      final windowAlreadyCompleted =
          currentWindowCode != null &&
          (_completedWindowCodes.contains(currentWindowCode) ||
              (latestCounted != null &&
                  latestCounted['workDate']?.toString() == currentWorkDate &&
                  latestCounted['windowCode']?.toString() == currentWindowCode));
      final canScanAttendanceDirectly =
          windowInfo != null &&
          !windowAlreadyCompleted &&
          (_pendingLookup == null ||
              _pendingLookup!.state == PendingAttendanceRequestState.absent);

      return TechnicianJobActionZone(
        data: _techData,
        selectedJob: _selectedTechJob,
        actionInProgress: _actionInProgress,
        stageLabel: _checkInStageLabel,
        errorMessage: _actionError,
        alreadyClockedIn: _hasScannedAttendanceToday,
        openAttendanceWindowLabel: canScanAttendanceDirectly
            ? AppStrings.scanWindowLabel(windowInfo.label)
            : null,
        openAttendanceWindowKind: canScanAttendanceDirectly
            ? windowInfo.kind
            : null,
        openAttendanceWindowIcon: canScanAttendanceDirectly
            ? windowInfo.icon
            : null,
        onScanAttendance: canScanAttendanceDirectly
            ? () => _checkIn(windowCode: currentWindowCode!)
            : null,
        onRetry: _loadInitial,
        onSelectJob: (job) => setState(() {
          _selectedTechJob = job;
          _actionError = null;
        }),
        onClearJob: () => setState(() {
          _selectedTechJob = null;
          _actionError = null;
        }),
        onCheckIn: _technicianCheckIn,
        onCheckOut: _technicianCheckOut,
        onBreak: _technicianBreak,
        onResumeFromBreak: _technicianResumeFromBreak,
        onEndFromBreak: _technicianEndFromBreak,
        onWriteReport: _openTechnicianReport,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _actionZone(context),
    );
  }

  TechnicianJob? _currentTechnicianDetailJob() {
    if (!_isTechnician) return null;
    final active = _techData?.activeSession;
    if (active != null && _techData != null) {
      for (final j in _techData!.jobs) {
        if (j.id == active.jobId) return j;
      }
    }
    return _selectedTechJob;
  }

  Widget _mobileActivitySheet(BuildContext context) {
    final detailJob = _currentTechnicianDetailJob();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status == null)
              StatusBanner(
                variant: StatusVariant.error,
                message: _statusError ?? 'Status unavailable.',
              )
            else
              _mobileWindowStepper(context),
            if (detailJob != null) ...[
              const Divider(height: AppSpacing.xl),
              TechnicianSelectedJobDetails(
                job: detailJob,
                isActive: _techData?.activeSession != null,
              ),
            ],
            const Divider(height: AppSpacing.xl),
            _mobileTodaysActivity(context),
          ],
        ),
      ),
    );
  }

  Widget _mobileWindowStepper(BuildContext context) {
    if (_status == null) return const SizedBox.shrink();
    final current = _windowStepOrder.indexOf(
      _status?['currentWindowCode']?.toString() ?? '',
    );
    final latest = _status?['latestCountedEvent'];
    final recorded = {
      ..._completedWindowCodes,
      if (latest is Map &&
          latest['workDate'] != null &&
          latest['workDate'] == _status?['currentWorkDate'])
        latest['windowCode'],
    };
    final lastRecorded = _windowStepOrder.lastIndexWhere(recorded.contains);
    final position = current >= 0 ? current : lastRecorded;
    final next = position + 1;
    final String guidance;
    if (current >= 0 && !recorded.contains(_windowStepOrder[current])) {
      final label = AppStrings.scanWindowLabel(
        _windowDisplayInfo[_windowStepOrder[current]]!.label,
      );
      guidance = AppStrings.isThai
          ? 'เปิดให้ลงเวลาช่วง$labelแล้ว'
          : '$label window is open';
    } else if (current < 0 && position < _windowStepOrder.length - 1) {
      guidance = AppStrings.t(
        'No active window · Opening time unavailable',
        'ไม่อยู่ในช่วงเวลาสแกน · ยังไม่เปิดช่วงถัดไป',
      );
    } else if (next < _windowStepOrder.length) {
      final nextLabel = AppStrings.scanWindowLabel(
        _windowDisplayInfo[_windowStepOrder[next]]!.label,
      );
      guidance = AppStrings.isThai
          ? 'ช่วงถัดไป: $nextLabel'
          : 'Next: $nextLabel · Opening time unavailable';
    } else {
      guidance = AppStrings.t(
        'No further windows today',
        'ครบทุกช่วงเวลาลงงานของวันนี้แล้ว',
      );
    }
    Color segmentColor(int leftIdx, int rightIdx) {
      if (rightIdx <= position) {
        if (rightIdx == current) return AppColors.secondary;
        if (recorded.contains(_windowStepOrder[leftIdx]) ||
            recorded.contains(_windowStepOrder[rightIdx])) {
          return AppColors.success;
        }
        return AppColors.neutral.withValues(alpha: 0.28);
      }
      return AppColors.cardBorder;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _windowStepOrder.length; i++)
              Expanded(
                child: _windowStepItem(
                  index: i,
                  completed: recorded.contains(_windowStepOrder[i]),
                  current: i == current,
                  past: i < position,
                  leftTrackColor: i == 0
                      ? Colors.transparent
                      : segmentColor(i - 1, i),
                  rightTrackColor: i == _windowStepOrder.length - 1
                      ? Colors.transparent
                      : segmentColor(i, i + 1),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(guidance, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _windowStepItem({
    required int index,
    required bool completed,
    required bool current,
    required bool past,
    required Color leftTrackColor,
    required Color rightTrackColor,
  }) {
    final info = _windowDisplayInfo[_windowStepOrder[index]]!;
    final foreground = completed
        ? AppColors.success
        : current
        ? AppColors.neutral
        : AppColors.textSecondary;
    final state = completed
        ? AppStrings.t('Recorded', 'บันทึกแล้ว')
        : current
        ? AppStrings.t('Open', 'เปิดอยู่')
        : past
        ? AppStrings.t('Passed', 'ผ่านแล้ว')
        : AppStrings.t('Pending', 'รอเวลา');
    final displayLabel = AppStrings.scanWindowLabel(info.label);
    return Semantics(
      label: [displayLabel, state, if (current) 'Current window'].join(', '),
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: leftTrackColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(2),
                    ),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current
                      ? AppColors.secondary
                      : completed
                      ? AppColors.successContainer
                      : AppColors.surface,
                  border: Border.all(
                    color: current
                        ? AppColors.secondary
                        : completed
                        ? AppColors.success
                        : past
                        ? AppColors.neutral.withValues(alpha: 0.28)
                        : AppColors.cardBorder,
                    width: (current || completed) ? 1.6 : 1.0,
                  ),
                  boxShadow: current
                      ? [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.36),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  completed
                      ? Icons.check_rounded
                      : past
                      ? Icons.remove_rounded
                      : info.icon,
                  size: 17,
                  color: current ? AppColors.neutral : foreground,
                ),
              ),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: rightTrackColor,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            state,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileTodaysActivity(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = _status;

    Widget header({Widget? trailing}) => Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Text(
          AppStrings.t("TODAY'S ACTIVITY", 'กิจกรรมวันนี้'),
          style: textTheme.labelLarge,
        ),
        ?trailing,
      ],
    );

    if (status == null) {
      return header();
    }

    final workDate = status['currentWorkDate']?.toString() ?? '-';
    final rawLatestEvent = status['latestEvent'] as Map<String, dynamic>?;
    final isLatestEventToday =
        rawLatestEvent != null &&
        rawLatestEvent['workDate']?.toString() == workDate;
    final latestEvent = isLatestEventToday ? rawLatestEvent : null;

    if (latestEvent == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(),
          const SizedBox(height: AppSpacing.sm),
          if (_isTechnician &&
              _techData != null &&
              _techData!.todaySessions.isNotEmpty)
            TechnicianTodaySessionsList(sessions: _techData!.todaySessions)
          else
            Text(
              AppStrings.t(
                'No attendance recorded yet today.',
                'ยังไม่มีการลงเวลาในวันนี้',
              ),
              style: textTheme.bodyMedium,
            ),
        ],
      );
    }

    final counted = latestEvent['counted'];
    final notCountedReason = latestEvent['notCountedReason']?.toString();
    final flag = latestEvent['flag']?.toString();
    final lateMinutes = _positiveMinutes(latestEvent['lateMinutes']);
    final earlyLeaveMinutes = _positiveMinutes(
      latestEvent['earlyLeaveMinutes'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header(
          trailing: StatusChip(
            label: counted == true
                ? AppStrings.t('Counted', 'นับเวลาแล้ว')
                : AppStrings.t('Not counted', 'ไม่นับเวลา'),
            variant: counted == true
                ? ChipVariant.success
                : ChipVariant.warning,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.t('Latest scan', 'สแกนล่าสุด'),
          style: textTheme.bodySmall,
        ),
        Text(
          _formatScannedAt(latestEvent['scannedAt']?.toString()),
          style: textTheme.titleMedium,
        ),
        if (counted == false && notCountedReason != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: StatusBanner(
              variant: StatusVariant.warning,
              message: _notCountedMessage(notCountedReason),
            ),
          ),
        if (flag != null)
          _MetaLine(
            icon: Icons.flag_outlined,
            text: AppStrings.isThai ? 'สถานะ: $flag' : 'Flag: $flag',
            color: AppColors.textSecondary,
          ),
        if (lateMinutes != null)
          _MetaLine(
            icon: Icons.schedule,
            text: AppStrings.isThai
                ? 'มาสาย: $lateMinutes นาที'
                : 'Late: $lateMinutes minutes',
            color: AppColors.warning,
          ),
        if (earlyLeaveMinutes != null)
          _MetaLine(
            icon: Icons.schedule,
            text: AppStrings.isThai
                ? 'ออกก่อนเวลา: $earlyLeaveMinutes นาที'
                : 'Early Leave: $earlyLeaveMinutes minutes',
            color: AppColors.warning,
          ),
        if (_isTechnician &&
            _techData != null &&
            _techData!.todaySessions.isNotEmpty)
          TechnicianTodaySessionsList(sessions: _techData!.todaySessions),
      ],
    );
  }

  Widget _desktopLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelDecoration = BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(AppRadius.surface),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            primary: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: panelDecoration,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _heroBand(context),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isTechnician)
                                _mobileActionZone(context)
                              else ...[
                                _statusStrip(context),
                                const SizedBox(height: AppSpacing.lg),
                                ..._actionZone(context),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: panelDecoration,
                    child: SingleChildScrollView(
                      primary: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _mobileWindowStepper(context),
                          const SizedBox(height: AppSpacing.xl),
                          _todaysActivity(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroBand(BuildContext context) {
    final workDate = _status?['currentWorkDate']?.toString();
    return AmbientPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _greeting(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_isTechnician) const TechnicianRoleBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatDate(workDate),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onNeutralMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LiveClock(
            style: Theme.of(context).textTheme.displayMedium!
                .copyWith(color: Colors.white, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _statusStrip(BuildContext context) {
    if (_status == null) {
      return StatusBanner(
        variant: StatusVariant.error,
        message: _statusError ?? 'Status unavailable.',
      );
    }

    final status = _status!;
    final windowCode = status['currentWindowCode']?.toString();
    final windowInfo = windowCode == null
        ? null
        : _windowDisplayInfo[windowCode];
    final windowLabel = windowCode == null
        ? AppStrings.t('No active window', 'ไม่อยู่ในช่วงเวลาสแกน')
        : (windowInfo != null
              ? AppStrings.scanWindowLabel(windowInfo.label)
              : 'Unrecognized window ($windowCode)');

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        StatusChip(
          label: windowLabel,
          variant: windowInfo != null
              ? ChipVariant.active
              : (windowCode == null ? ChipVariant.info : ChipVariant.warning),
          icon: Icons.schedule,
        ),
      ],
    );
  }

  // claude_prompt.txt (v116 -- Harden Pending Checkout Idempotency,
  // Cleanup and UI State §6 "Pending Checkout UI Status Guard"): an
  // actionable confirmation button is shown ONLY when
  // `pendingCheckoutCheckStatus == 'ok'` AND a non-empty `workDate` is
  // present -- a missing/null/unexpected status value is never treated
  // as implicitly `'ok'`. The backend's own status contract is unchanged;
  // this only changes how this client reacts to it.
  List<Widget> _pendingCheckoutSection(BuildContext context) {
    final checkStatus = _status?['pendingCheckoutCheckStatus']?.toString();

    if (checkStatus == 'invalid_leave_window_configuration') {
      return const [
        StatusBanner(
          variant: StatusVariant.error,
          title: 'Pending Checkout',
          message:
              'The Leave window configuration is invalid, so a forgotten '
              'checkout cannot be confirmed right now. Contact your '
              'administrator.',
        ),
        SizedBox(height: AppSpacing.lg),
      ];
    }

    final pendingCheckout =
        _status?['pendingCheckout'] as Map<String, dynamic>?;

    if (checkStatus != 'ok') {
      // Null, missing, or any other unexpected value. If there is also
      // nothing pending to report, stay silent (the common, no-op case --
      // nothing wrong to flag). Otherwise there IS a pending item this
      // client is deliberately refusing to let the user act on, so an
      // explicit "could not be confirmed" message is shown instead of a
      // button with a disabled/null `onPressed` masquerading as present.
      if (pendingCheckout == null) return const [];
      return const [
        StatusBanner(
          variant: StatusVariant.error,
          title: 'Pending Checkout',
          message:
              'Pending Checkout status could not be confirmed. Please '
              'refresh and try again.',
        ),
        SizedBox(height: AppSpacing.lg),
      ];
    }

    if (pendingCheckout == null) return const [];

    final workDate = pendingCheckout['workDate']?.toString();

    if (workDate == null || workDate.isEmpty) {
      // `pendingCheckoutCheckStatus == 'ok'` but the pending record itself
      // is missing a usable work date -- "a valid pending work date
      // exists" is not satisfied, so no actionable button is shown here
      // either.
      return const [
        StatusBanner(
          variant: StatusVariant.error,
          title: 'Pending Checkout',
          message:
              'Pending Checkout information is incomplete. Please refresh '
              'and try again.',
        ),
        SizedBox(height: AppSpacing.lg),
      ];
    }

    final originalInEvent =
        pendingCheckout['originalInEvent'] as Map<String, dynamic>?;

    return [
      const StatusBanner(
        variant: StatusVariant.warning,
        title: 'Pending Checkout',
        message:
            'A Leave checkout for this work date has not been recorded. '
            'Please confirm if you completed work on this date.',
      ),
      const SizedBox(height: AppSpacing.md),
      DetailRow(
        icon: Icons.event_outlined,
        label: 'Pending work date',
        value: _formatDate(workDate),
      ),
      if (originalInEvent != null)
        DetailRow(
          icon: Icons.login,
          label: 'Original check-in',
          value: _formatScannedAt(originalInEvent['scannedAt']?.toString()),
        ),
      const SizedBox(height: AppSpacing.md),
      PrimaryActionButton(
        label: 'Confirm Leave Checkout',
        loading: _actionInProgress,
        onPressed: _actionInProgress
            ? null
            : () => _confirmPendingCheckout(workDate),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _actionZone(BuildContext context) {
    final widgets = <Widget>[];

    widgets.addAll(_pendingCheckoutSection(context));

    if (_actionError != null) {
      widgets.add(
        StatusBanner(variant: StatusVariant.error, message: _actionError!),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }

    // claude_prompt.txt (v171 §5 "allow safe retry without duplicate
    // upload"): the Web-only in-memory fallback's own equivalent of this
    // banner -- on every other platform, the SAME condition is already
    // covered by `_pendingLookup`'s own `valid` state below (a durably
    // persisted record with a photo but no storageKey yet also renders
    // the "Retry" banner/button), so no separate banner is needed there.
    if (kIsWeb && _webInMemoryPhoto != null && !_actionInProgress) {
      widgets.addAll([
        const StatusBanner(
          variant: StatusVariant.warning,
          message:
              'A captured attendance photo could not be uploaded. Tap '
              'Retry to upload it without retaking the photo.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ]);
    }

    // claude_prompt.txt (v161 §7 "show upload progress / submission
    // progress separately where practical"): names the specific
    // in-progress step without altering the Check-In button's own label
    // or design.
    if (_checkInStageLabel != null) {
      widgets.addAll([
        Text(
          _checkInStageLabel!,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: AppSpacing.sm),
      ]);
    }

    final lookup = _pendingLookup;
    if (lookup == null) {
      widgets.addAll([
        StatusBanner(
          variant: StatusVariant.error,
          message:
              _pendingError ?? 'Unable to determine pending request state.',
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryActionButton(label: 'Try again', onPressed: _loadPendingOnly),
      ]);
      return widgets;
    }

    if (lookup.conflictingLegacyRecord != null) {
      widgets.addAll([
        const StatusBanner(
          variant: StatusVariant.warning,
          message:
              'A conflicting earlier attendance request was found for '
              'your account. Please contact your administrator for '
              'assistance.',
        ),
        const SizedBox(height: AppSpacing.lg),
      ]);
    }

    widgets.addAll(_buildPrimaryAction(lookup.state));
    return widgets;
  }

  List<Widget> _buildCheckInAction() {
    final status = _status;
    final currentWorkDate = status?['currentWorkDate']?.toString();
    final currentWindowCode = status?['currentWindowCode']?.toString();

    if (currentWindowCode == null) {
      return [
        TimeActionButton(
          label: AppStrings.t('Check In', 'ลงเวลาเข้า'),
          icon: Icons.schedule,
          enabled: false,
          onPressed: null,
          hint: AppStrings.t(
            'Opens in a scheduled window',
            'เปิดให้กดในช่วงเวลาที่กำหนด',
          ),
        ),
      ];
    }

    final windowInfo = _windowDisplayInfo[currentWindowCode];
    if (windowInfo == null) {
      return [
        TimeActionButton(
          label: AppStrings.t('Check In', 'ลงเวลาเข้า'),
          icon: Icons.schedule,
          enabled: false,
          onPressed: null,
          hint: AppStrings.t(
            'Opens in a scheduled window',
            'เปิดให้กดในช่วงเวลาที่กำหนด',
          ),
        ),
      ];
    }

    final latestCountedEvent =
        status?['latestCountedEvent'] as Map<String, dynamic>?;
    final alreadyCompleted =
        latestCountedEvent != null &&
        latestCountedEvent['workDate']?.toString() == currentWorkDate &&
        latestCountedEvent['windowCode']?.toString() == currentWindowCode;

    final actionLabel = windowInfo.kind == 'in'
        ? AppStrings.t('Check In', 'ลงเวลาเข้า')
        : AppStrings.t('Check Out', 'ลงเวลาออก');
    final displayWindowLabel = AppStrings.scanWindowLabel(windowInfo.label);

    if (alreadyCompleted) {
      return [
        TimeActionButton(
          label: actionLabel,
          icon: Icons.check_circle_outline,
          enabled: false,
          onPressed: null,
          hint: AppStrings.isThai
              ? '$displayWindowLabel • บันทึกแล้ว'
              : '${windowInfo.label} • Already recorded',
        ),
      ];
    }

    return [
      TimeActionButton(
        label: actionLabel,
        icon: windowInfo.icon,
        hint: displayWindowLabel,
        loading: _actionInProgress,
        onPressed: () => _checkIn(windowCode: currentWindowCode),
      ),
    ];
  }

  List<Widget> _buildPrimaryAction(PendingAttendanceRequestState state) {
    switch (state) {
      case PendingAttendanceRequestState.absent:
        return _buildCheckInAction();
      case PendingAttendanceRequestState.valid:
        // claude_prompt.txt (v171 §3 "including the selected attendance
        // action/window"): the pending record's own stored `windowCode`
        // (set once, at the start of the attempt -- never the CURRENT
        // window, which may have since advanced) is surfaced here purely
        // as informational text; it does not change which window is
        // blocked or how the retry itself behaves.
        final pendingWindowCode = _pendingLookup?.record?['windowCode'];
        final pendingWindowLabel = pendingWindowCode is String
            ? _windowDisplayInfo[pendingWindowCode]?.label
            : null;
        return [
          StatusBanner(
            variant: StatusVariant.warning,
            message: pendingWindowLabel != null
                ? 'A check-in for $pendingWindowLabel is waiting to be sent.'
                : 'A check-in is waiting to be sent.',
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryCtaButton(
            label: AppStrings.t('Retry', 'ลองอีกครั้ง'),
            loading: _actionInProgress,
            onPressed: () => _checkIn(
              windowCode: _status?['currentWindowCode']?.toString() ?? '',
            ),
          ),
        ];
      case PendingAttendanceRequestState.malformed:
        return [
          StatusBanner(
            variant: StatusVariant.error,
            message: AppStrings.t(
              'A stored check-in could not be read and cannot be retried.',
              'ไม่สามารถอ่านรายการลงเวลาที่ค้างอยู่ได้',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryActionButton(
            label: AppStrings.t('Discard', 'ลบทิ้ง'),
            loading: _actionInProgress,
            onPressed: _discard,
          ),
        ];
    }
  }

  Widget _todaysActivity(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = _status;

    Widget sectionLabel() =>
        Text("TODAY'S ACTIVITY", style: textTheme.labelSmall);

    if (status == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(),
          const SizedBox(height: AppSpacing.sm),
        ],
      );
    }

    final workDate = status['currentWorkDate']?.toString() ?? '-';
    final rawLatestEvent = status['latestEvent'] as Map<String, dynamic>?;
    final isLatestEventToday =
        rawLatestEvent != null &&
        rawLatestEvent['workDate']?.toString() == workDate;
    final latestEvent = isLatestEventToday ? rawLatestEvent : null;

    if (latestEvent == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No attendance recorded yet today.',
            style: textTheme.bodyMedium,
          ),
        ],
      );
    }

    final counted = latestEvent['counted'];
    final notCountedReason = latestEvent['notCountedReason']?.toString();
    final flag = latestEvent['flag']?.toString();
    final lateMinutes = _positiveMinutes(latestEvent['lateMinutes']);
    final earlyLeaveMinutes = _positiveMinutes(
      latestEvent['earlyLeaveMinutes'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionLabel(),
        const Divider(height: AppSpacing.lg),
        DetailRow(
          icon: Icons.login,
          label: 'Last check-in',
          value: latestEvent['scannedAt']?.toString() ?? '-',
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: StatusChip(
            label: counted == true ? 'Counted' : 'Not counted',
            variant: counted == true
                ? ChipVariant.success
                : ChipVariant.warning,
          ),
        ),
        if (counted == false && notCountedReason != null)
          _MetaLine(
            icon: Icons.info_outline,
            text: _notCountedMessage(notCountedReason),
            color: AppColors.warning,
          ),
        if (flag != null)
          _MetaLine(
            icon: Icons.flag_outlined,
            text: 'Flag: $flag',
            color: AppColors.textSecondary,
          ),
        if (lateMinutes != null)
          _MetaLine(
            icon: Icons.schedule,
            text: 'Late: $lateMinutes minutes',
            color: AppColors.warning,
          ),
        if (earlyLeaveMinutes != null)
          _MetaLine(
            icon: Icons.schedule,
            text: 'Early Leave: $earlyLeaveMinutes minutes',
            color: AppColors.warning,
          ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
