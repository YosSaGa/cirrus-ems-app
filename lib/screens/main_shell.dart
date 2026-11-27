import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_side_nav.dart';
import '../widgets/pay_wallet_card.dart';
import 'attendance_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'work_trial_screen.dart';

// claude_prompt.txt (v123 -- Implement Bottom Navigation Shell): the new
// top-level destination SplashScreen/LoginScreen now navigate to instead
// of AttendanceScreen directly (see those two files' own updated comments).
// This widget owns ONLY tab selection -- no Attendance/History/Profile
// business logic lives here (task §5 "keep navigation logic separate from
// individual screen business logic" / "do not duplicate Attendance logic
// in the navigation shell").
//
// `IndexedStack` (not a per-tap `Navigator`) is deliberate: tab State stays
// alive while navigation only changes visibility. Theme listeners rebuild
// each screen widget with a stable key so its colors refresh without
// disposing the screen State or repeating initState-driven requests.
//
// AttendanceScreen and ProfileScreen are each still their own complete,
// unmodified `Scaffold` (AttendanceScreen keeps its existing AppBar with
// Refresh/Profile/Sign-out actions; ProfileScreen keeps its own AppBar).
// Nesting a Scaffold inside this shell's body is intentional, not an
// oversight -- it is the smallest-risk way to satisfy "preserve the
// current Attendance UI" and "do not modify attendance-related services
// unless strictly necessary for integration" while still adding a
// persistent bottom nav bar beneath it. This does mean Profile is now
// reachable two ways (the bottom tab, and AttendanceScreen's own AppBar
// icon, which still pushes a second, separate ProfileScreen instance on
// top of the stack) -- flagged in this round's PROGRESS_LOG.md report as a
// known redundancy, intentionally left alone rather than trimming
// AttendanceScreen's AppBar, which this task did not ask for.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  /// Lazily hydrate non-initial tabs on first visit so Splash -> Attendance
  /// only builds and fetches AttendanceScreen (eliminating the 4-tab startup
  /// build & network spike), while preserving state once visited.
  final Set<int> _visitedTabs = {0};

  static final Listenable _shellListenable = Listenable.merge([
    ThemeService.themeModeNotifier,
    LanguageService.languageNotifier,
  ]);

  // Each tab listens for theme and language changes independently. Rebuilding
  // the screen widget with the same key refreshes colors and copy while
  // retaining its State.
  static Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return ListenableBuilder(
          listenable: _shellListenable,
          builder: (_, _) =>
              AttendanceScreen(key: const ValueKey('attendance-tab')),
        );
      case 1:
        return ListenableBuilder(
          listenable: _shellListenable,
          builder: (_, _) => HistoryScreen(key: const ValueKey('history-tab')),
        );
      case 2:
        return ListenableBuilder(
          listenable: _shellListenable,
          builder: (_, _) =>
              WorkTrialScreen(key: const ValueKey('pay-leave-tab')),
        );
      case 3:
      default:
        return ListenableBuilder(
          listenable: _shellListenable,
          builder: (_, _) => ProfileScreen(key: const ValueKey('profile-tab')),
        );
    }
  }

  final List<Widget?> _cachedTabs = List<Widget?>.filled(4, null);
  final _scrollControllers = List.generate(4, (_) => ScrollController());

  void _selectTab(int index) {
    if (index != _index) {
      for (final position in _scrollControllers[_index].positions.toList()) {
        position.jumpTo(position.minScrollExtent);
      }
      PayWalletCard.resetAllToFront();
      setState(() {
        _visitedTabs.add(index);
        _index = index;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Widget> get _scopedTabs => [
    for (var i = 0; i < 4; i++)
      _visitedTabs.contains(i)
          ? PrimaryScrollController(
              controller: _scrollControllers[i],
              child: _cachedTabs[i] ??= _buildTab(i),
            )
          : const SizedBox.shrink(),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _shellListenable,
      builder: (context, _) {
        if (AppBreakpoints.isDesktop(context)) {
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: Row(
              children: [
                AppSideNav(currentIndex: _index, onTap: _selectTab),
                Expanded(
                  child: IndexedStack(index: _index, children: _scopedTabs),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.primary,
          extendBody: true,
          body: IndexedStack(index: _index, children: _scopedTabs),
          bottomNavigationBar: AppBottomNav(
            currentIndex: _index,
            onTap: _selectTab,
          ),
        );
      },
    );
  }
}
