import 'dart:async';

import 'package:flutter/material.dart';

// claude_prompt.txt (v98 Phase 2 -- Full UX/UI Redesign Implementation §4
// "Attendance-Specific Requirements"): a separate StatefulWidget owning
// only its own periodic timer. `initState` creates exactly one
// `Timer.periodic`; `dispose` cancels it unconditionally before
// `super.dispose()` -- no second timer is ever created without the widget
// being disposed first (guaranteed by Flutter's own State lifecycle: a
// given State instance's `initState` runs exactly once per mount).
// `setState` here rebuilds only this small widget, never the parent
// screen, so a once-per-second tick never triggers a full-screen rebuild.
//
// This widget is DISPLAY-ONLY. It reads the clock purely for presentation
// and never calls any AttendanceService method, never computes a work date
// or window, and never determines Check-In eligibility -- the Backend's
// own `GET /app-attendance/status` response remains the sole source of
// `currentWorkDate`/`currentWindowCode`, unchanged. This widget has no
// awareness of Attendance state at all.
//
// claude_prompt.txt (v99 §5): displays Bangkok time (UTC+7) rather than
// the device's own local time -- `DateTime.now().toUtc().add(const
// Duration(hours: 7))`, no DST in Bangkok so a fixed offset is correct
// year-round. Still exactly one `Timer.periodic`, still display-only.
class LiveClock extends StatefulWidget {
  const LiveClock({super.key, this.style});

  final TextStyle? style;

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late DateTime _now;
  Timer? _timer;

  static DateTime _bangkokNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 7));

  @override
  void initState() {
    super.initState();
    _now = _bangkokNow();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = _bangkokNow());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final time =
        '${_twoDigits(_now.hour)}:${_twoDigits(_now.minute)}:${_twoDigits(_now.second)}';

    final baseStyle =
        widget.style ?? Theme.of(context).textTheme.displayMedium!;

    return RepaintBoundary(
      child: Text(
        time,
        style: baseStyle.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
