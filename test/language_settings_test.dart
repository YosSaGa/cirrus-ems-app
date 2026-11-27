import 'package:cirrus_app/l10n/app_strings.dart';
import 'package:cirrus_app/screens/settings_screen.dart';
import 'package:cirrus_app/services/language_service.dart';
import 'package:cirrus_app/services/theme_service.dart';
import 'package:cirrus_app/theme/app_theme.dart';
import 'package:cirrus_app/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeService.debugReset();
    LanguageService.debugReset();
  });

  tearDown(() {
    ThemeService.debugReset();
    LanguageService.debugReset();
  });

  test('LanguageService defaults to English and persists Thai selection', () async {
    await LanguageService.init();
    expect(LanguageService.currentLanguage, AppLanguage.en);
    expect(AppStrings.isThai, isFalse);

    await LanguageService.setLanguage(AppLanguage.th);
    expect(LanguageService.currentLanguage, AppLanguage.th);
    expect(AppStrings.isThai, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ems.language'), 'th');

    // Re-init from persisted prefs
    LanguageService.debugReset();
    await LanguageService.init();
    expect(LanguageService.currentLanguage, AppLanguage.th);
  });

  test('AppTheme switches font family to IBMPlexSansThai when Thai is active', () {
    final enTheme = AppTheme.forMode(
      AppThemeMode.defaultTheme,
      language: AppLanguage.en,
    );
    expect(enTheme.textTheme.titleLarge?.fontFamily, 'BebasNeue');

    final thTheme = AppTheme.forMode(
      AppThemeMode.defaultTheme,
      language: AppLanguage.th,
    );
    expect(thTheme.textTheme.titleLarge?.fontFamily, 'IBMPlexSansThai');
  });

  testWidgets(
    'SettingsScreen opens LanguageSettingsScreen and switches UI between EN and TH',
    (tester) async {
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: Listenable.merge([
            ThemeService.themeModeNotifier,
            LanguageService.languageNotifier,
          ]),
          builder: (context, _) {
            return MaterialApp(
              theme: AppTheme.forMode(
                ThemeService.currentMode,
                language: LanguageService.currentLanguage,
              ),
              home: const SettingsScreen(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English (US)'), findsOneWidget);

      // Open LanguageSettingsScreen
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSettingsScreen), findsOneWidget);
      expect(find.text('DISPLAY LANGUAGE'), findsOneWidget);
      expect(find.text('ภาษาไทย'), findsOneWidget);

      // Switch to Thai
      await tester.tap(find.byKey(const ValueKey('language-option-th')));
      await tester.pump();
      expect(find.text('UPDATING'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();

      expect(LanguageService.currentLanguage, AppLanguage.th);
      expect(find.text('เปลี่ยนภาษาแล้ว'), findsOneWidget);
      expect(find.text('ภาษาที่แสดงผล'), findsOneWidget);
      expect(find.text('กำลังใช้งาน'), findsOneWidget);

      // Navigate back to SettingsScreen — should now be in Thai
      Navigator.of(tester.element(find.byType(LanguageSettingsScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.text('ตั้งค่า'), findsOneWidget);
      expect(find.text('รูปลักษณ์'), findsOneWidget);
      expect(find.text('ภาษา'), findsOneWidget);
      expect(find.text('ภาษาไทย (Thai)'), findsOneWidget);

      // Re-open LanguageSettingsScreen and switch to Bahasa Melayu (MS)
      await tester.tap(find.text('ภาษา'));
      await tester.pumpAndSettle();
      expect(find.text('Bahasa Melayu'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('language-option-ms')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();

      expect(LanguageService.currentLanguage, AppLanguage.ms);
      expect(find.text('BAHASA PAPARAN'), findsOneWidget);
      expect(find.text('AKTIF'), findsOneWidget);
    },
  );

  testWidgets('AppBottomNav reactively updates destination labels to Thai', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(currentIndex: 0, onTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Pay & Leave'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await LanguageService.setLanguage(AppLanguage.th);
    await tester.pumpAndSettle();

    expect(find.text('ลงเวลา'), findsOneWidget);
    expect(find.text('ประวัติ'), findsOneWidget);
    expect(find.text('ค่าแรงและลา'), findsOneWidget);
    expect(find.text('โปรไฟล์'), findsOneWidget);
  });
}
