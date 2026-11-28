import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/work_trial_store.dart';
import '../theme/app_theme.dart';
import '../widgets/pay_wallet_card.dart';
import 'earnings_trial_tab.dart';
import 'leave_trial_tab.dart';

class WorkTrialScreen extends StatefulWidget {
  const WorkTrialScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  State<WorkTrialScreen> createState() => _WorkTrialScreenState();
}

class _WorkTrialScreenState extends State<WorkTrialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _lastTab = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.index == _lastTab) return;
    _lastTab = _tabs.index;
    PayWalletCard.resetAllToFront();
    final controller = PrimaryScrollController.maybeOf(context);
    if (controller == null) return;
    for (final position in controller.positions.toList()) {
      position.jumpTo(position.minScrollExtent);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  late final Future<WorkTrialStore> _store = _loadStore();
  Future<WorkTrialStore> _loadStore() async {
    final user = await AuthService.getSavedUser();
    final id = user?['id'];
    if (id is! String || id.trim().isEmpty) {
      throw StateError('Please sign in to use the pay and leave trial');
    }
    return WorkTrialStore(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    appBar: AppBar(
      leading: widget.onOpenDrawer != null
          ? IconButton(
              tooltip: AppStrings.t('Menu', 'เมนู', 'Menu'),
              onPressed: widget.onOpenDrawer,
              icon: const Icon(Icons.menu_rounded),
            )
          : null,
      title: Text(AppStrings.t('Earnings & Leave', 'ค่าแรงและวันลา')),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.neutral,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            labelColor: AppColors.onNeutral,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
            tabs: [
              Tab(text: AppStrings.t('Pay estimate', 'ประมาณการค่าแรง')),
              Tab(text: AppStrings.t('Local leave', 'ใบลาในเครื่อง')),
            ],
          ),
        ),
      ),
    ),
    body: FutureBuilder<WorkTrialStore>(
      future: _store,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(snapshot.error.toString()),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return TabBarView(
          controller: _tabs,
          children: [
            EarningsTrialTab(store: snapshot.data!),
            LeaveTrialTab(store: snapshot.data!),
          ],
        );
      },
    ),
  );
}
