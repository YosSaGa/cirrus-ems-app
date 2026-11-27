import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_bottom_nav.dart';
import 'app_logo.dart';

/// Desktop navigation: the same four destinations as [AppBottomNav], shown as
/// a navy rail on wide viewports where a floating phone-style bar would be
/// out of place.
class AppSideNav extends StatelessWidget {
  const AppSideNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final destinations = appNavDestinations;
    return Container(
      width: 104,
      color: AppColors.sideNavBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.xl),
            child: AppLogo(size: 40),
          ),
          for (var index = 0; index < destinations.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SideNavItem(
                icon: destinations[index].icon,
                label: destinations[index].label,
                active: index == currentIndex,
                onTap: () => onTap(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active ? AppColors.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.10),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: active
                      ? AppColors.timeActionForeground
                      : AppColors.onNeutralMuted,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? AppColors.timeActionForeground
                        : AppColors.onNeutralMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
