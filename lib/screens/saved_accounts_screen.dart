import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/app_preferences_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Full list of previously switched accounts on this device, allowing the user
/// to search, remove entries, or switch to any saved account beyond the 3
/// most recent accounts shown in the quick sheet.
class SavedAccountsScreen extends StatefulWidget {
  const SavedAccountsScreen({
    super.key,
    required this.currentUsername,
  });

  final String currentUsername;

  @override
  State<SavedAccountsScreen> createState() => _SavedAccountsScreenState();
}

class _SavedAccountsScreenState extends State<SavedAccountsScreen> {
  final _searchController = TextEditingController();
  List<RecentAccount> _accounts = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await AuthService.getRecentAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = items;
      _loading = false;
    });
  }

  List<RecentAccount> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _accounts;
    return _accounts.where((a) {
      return a.name.toLowerCase().contains(q) ||
          a.username.toLowerCase().contains(q) ||
          (a.employeeCode?.toLowerCase().contains(q) ?? false) ||
          (a.email?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final current = widget.currentUsername.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neutral,
        iconTheme: IconThemeData(color: AppColors.neutral),
        title: Text(
          AppStrings.t(
            'All Switched Accounts',
            'บัญชีที่เคยสลับทั้งหมด',
            'Semua Akaun Bertukar',
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: appContentMaxWidth(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: TextField(
                    key: const Key('saved-accounts-search-field'),
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: AppStrings.t(
                        'Search name, username, or employee code...',
                        'ค้นหาชื่อ ชื่อผู้ใช้ หรือรหัสพนักงาน...',
                        'Cari nama, pengguna, atau kod pekerja...',
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          color: AppColors.secondary,
                          onRefresh: _load,
                          child: items.isEmpty
                              ? ListView(
                                  padding: const EdgeInsets.all(32),
                                  children: [
                                    Icon(
                                      Icons.person_search_outlined,
                                      size: 46,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      AppStrings.t(
                                        'No saved accounts found.',
                                        'ไม่พบบัญชีที่บันทึกไว้',
                                        'Tiada akaun disimpan ditemui.',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    16,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (_, index) {
                                    final account = items[index];
                                    final isCurrent =
                                        account.username.toLowerCase() ==
                                        current;
                                    final instant = account.canInstantSwitch;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.surface,
                                        ),
                                        border: Border.all(
                                          color: isCurrent
                                              ? AppColors.secondary
                                              : AppColors.cardBorder,
                                          width: isCurrent ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: ListTile(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.surface,
                                            ),
                                          ),
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              AppColors.avatarBackground,
                                          child: Text(
                                            account.name.isNotEmpty
                                                ? account.name.characters.first
                                                      .toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              color: AppColors.avatarForeground,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          account.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.neutral,
                                          ),
                                        ),
                                        subtitle: Text(
                                          account.employeeCode != null &&
                                                  account
                                                      .employeeCode!
                                                      .isNotEmpty
                                              ? '${account.username} · #${account.employeeCode}'
                                              : account.username,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        trailing: isCurrent
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.secondary
                                                      .withValues(alpha: 0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.pill,
                                                      ),
                                                ),
                                                child: Text(
                                                  AppStrings.t(
                                                    'ACTIVE',
                                                    'กำลังใช้งาน',
                                                    'AKTIF',
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.secondary,
                                                  ),
                                                ),
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    instant
                                                        ? Icons.bolt_rounded
                                                        : Icons
                                                              .lock_outline_rounded,
                                                    size: 16,
                                                    color: instant
                                                        ? AppColors.secondary
                                                        : AppColors
                                                              .textSecondary,
                                                  ),
                                                  IconButton(
                                                    tooltip: AppStrings.t(
                                                      'Remove',
                                                      'ลบออก',
                                                      'Buang',
                                                    ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    icon: Icon(
                                                      Icons.close_rounded,
                                                      size: 18,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                    onPressed: () async {
                                                      if (AppPreferencesService
                                                          .hapticsEnabled) {
                                                        HapticFeedback.selectionClick();
                                                      }
                                                      await AuthService.removeRecentAccount(
                                                        account.username,
                                                      );
                                                      await _load();
                                                    },
                                                  ),
                                                ],
                                              ),
                                        onTap: () {
                                          if (AppPreferencesService
                                              .hapticsEnabled) {
                                            HapticFeedback.selectionClick();
                                          }
                                          Navigator.of(context).pop(
                                            isCurrent ? null : account,
                                          );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: FilledButton.icon(
                    key: const Key('saved-accounts-new-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neutral,
                      foregroundColor: AppColors.onNeutral,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: Text(
                      AppStrings.t(
                        'Use another account',
                        'เข้าสู่ระบบด้วยบัญชีอื่น',
                        'Guna akaun lain',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => Navigator.of(context).pop('NEW_ACCOUNT'),
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
