import 'dart:convert';

import 'package:cirrus_app/screens/profile_screen.dart';
import 'package:cirrus_app/screens/saved_accounts_screen.dart';
import 'package:cirrus_app/screens/settings_screen.dart';
import 'package:cirrus_app/services/app_preferences_service.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/services/language_service.dart';
import 'package:cirrus_app/services/theme_service.dart';
import 'package:cirrus_app/theme/app_theme.dart';
import 'package:cirrus_app/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: '', isOptional: true);
    SharedPreferences.setMockInitialValues({});
    ThemeService.debugReset();
    AppPreferencesService.debugReset();
  });

  tearDown(() {
    ThemeService.debugReset();
    AppPreferencesService.debugReset();
  });

  test(
    'ThemeService initializes, switches, and persists theme modes',
    () async {
      SharedPreferences.setMockInitialValues({'ems.themeMode': 'white'});
      await ThemeService.init();
      expect(ThemeService.currentMode, AppThemeMode.white);
      expect(AppColors.primary, const Color(0xFFFFFFFF));

      await ThemeService.setThemeMode(AppThemeMode.black);
      expect(ThemeService.currentMode, AppThemeMode.black);
      expect(AppColors.primary, const Color(0xFF0B1118));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ems.themeMode'), 'black');

      await ThemeService.setThemeMode(AppThemeMode.defaultTheme);
      expect(ThemeService.currentMode, AppThemeMode.defaultTheme);
      expect(AppColors.primary, const Color(0xFFF3F6F7));
      expect(prefs.getString('ems.themeMode'), 'default');
    },
  );

  testWidgets(
    'SettingsScreen has App Theme menu which opens ThemeSettingsScreen',
    (tester) async {
      await tester.pumpWidget(
        ValueListenableBuilder<AppThemeMode>(
          valueListenable: ThemeService.themeModeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              theme: AppTheme.forMode(mode),
              home: const SettingsScreen(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Cirrus Signature · Cirrus Navy'), findsOneWidget);

      // Tap Appearance menu -> opens AppearanceSettingsScreen
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();

      expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
      expect(find.text('App Theme'), findsOneWidget);
      expect(find.text('Pay Card Style'), findsOneWidget);

      // Tap App Theme menu -> opens ThemeSettingsScreen
      await tester.tap(find.text('App Theme'));
      await tester.pumpAndSettle();

      expect(find.byType(ThemeSettingsScreen), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('Pure White'), findsOneWidget);
      expect(find.text('Obsidian Black'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);

      // Switch to Pure White
      await tester.tap(find.text('Pure White'));
      await tester.pump();
      expect(find.text('CHANGING THEME'), findsOneWidget);
      expect(ThemeService.currentMode, AppThemeMode.defaultTheme);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump();
      expect(ThemeService.currentMode, AppThemeMode.white);
      expect(find.text('THEME UPDATED'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);

      // Switch to Obsidian Black
      await tester.tap(find.text('Obsidian Black'));
      await tester.pump();
      expect(find.text('CHANGING THEME'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump();
      expect(ThemeService.currentMode, AppThemeMode.black);
      expect(find.text('THEME UPDATED'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    },
  );

  testWidgets(
    'Appearance opens PayCardStyleScreen and updates card style via color circles',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forMode(AppThemeMode.defaultTheme),
          home: const AppearanceSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay Card Style'));
      await tester.pumpAndSettle();

      expect(find.byType(PayCardStyleScreen), findsOneWidget);
      expect(find.text('Cirrus Navy'), findsOneWidget);

      await tester.tap(find.byKey(const Key('card-swatch-obsidian_gold')));
      await tester.pumpAndSettle();

      expect(ThemeService.currentPayCardStyle, PayCardStyle.obsidianGold);
      expect(find.text('Obsidian Gold'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ems.payCardStyle'), 'obsidian_gold');

      await tester.tap(find.byKey(const Key('card-swatch-royal_burgundy')));
      await tester.pumpAndSettle();
      expect(ThemeService.currentPayCardStyle, PayCardStyle.royalBurgundy);
      expect(find.text('Royal Burgundy'), findsOneWidget);
    },
  );

  testWidgets('ProfileScreen opens SettingsScreen and reflects active theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({'id': 'emp-1', 'name': 'Somchai Test'}),
      'ems.authToken': 'mock-token',
    });
    AuthService.debugOverrideClient(
      MockClient((_) async {
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'emp-1',
              'name': 'Somchai Test',
              'email': 'somchai@cirrus.co.th',
            },
            'roles': ['Employee'],
          }),
          200,
        );
      }),
    );
    addTearDown(AuthService.debugResetClient);

    await tester.pumpWidget(
      ValueListenableBuilder<AppThemeMode>(
        valueListenable: ThemeService.themeModeNotifier,
        builder: (context, mode, _) {
          return MaterialApp(
            theme: AppTheme.forMode(mode),
            home: const ProfileScreen(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Cirrus Signature'), findsOneWidget);

    // Scroll to Settings and tap -> should open SettingsScreen
    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets(
    'ProfileScreen role badge has readable contrast in Obsidian Black mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 'emp-1', 'name': 'Admin User'}),
        'ems.authToken': 'mock-token',
        'ems.themeMode': 'black',
      });
      await ThemeService.init();
      AuthService.debugOverrideClient(
        MockClient((_) async {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'emp-1',
                'name': 'Admin User',
                'email': 'admin@cirrus.co.th',
              },
              'roles': ['ADMIN'],
            }),
            200,
          );
        }),
      );
      addTearDown(AuthService.debugResetClient);

      await tester.pumpWidget(
        ValueListenableBuilder<AppThemeMode>(
          valueListenable: ThemeService.themeModeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              theme: AppTheme.forMode(mode),
              home: const ProfileScreen(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final roleTextWidget = tester.widget<Text>(find.text('ADMIN'));
      expect(
        roleTextWidget.style?.color,
        AppThemePalette.blackPalette.roleBadgeForeground,
      );

      // Verify the badge container background is not white
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text('ADMIN'), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(
        decoration?.color,
        AppThemePalette.blackPalette.roleBadgeBackground,
      );
    },
  );

  testWidgets(
    'AppBottomNav reactively updates bubble and colors on theme change',
    (tester) async {
      ThemeService.debugReset();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(currentIndex: 0, onTap: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In default theme, bubble is Navy
      final bubbleFinder = find.byKey(const Key('nav-selection-bubble'));
      expect(bubbleFinder, findsOneWidget);
      var bubbleContainer = tester.widget<Container>(bubbleFinder);
      var decoration = bubbleContainer.decoration as BoxDecoration?;
      expect(decoration?.color, AppThemePalette.defaultPalette.bottomNavBubble);

      // Switch to black theme directly
      await ThemeService.setThemeMode(AppThemeMode.black);
      await tester.pumpAndSettle();

      // Bubble immediately updates to Neon Teal without tapping or scrolling
      bubbleContainer = tester.widget<Container>(bubbleFinder);
      decoration = bubbleContainer.decoration as BoxDecoration?;
      expect(decoration?.color, AppThemePalette.blackPalette.bottomNavBubble);
    },
  );

  testWidgets(
    'SettingsScreen toggles Haptic Feedback preference and opens DeviceCheckScreen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forMode(AppThemeMode.defaultTheme),
          home: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final hapticsSwitch = find.byKey(const Key('settings-haptics-switch'));
      expect(hapticsSwitch, findsOneWidget);
      expect(AppPreferencesService.hapticsEnabled, isTrue);

      await tester.tap(hapticsSwitch);
      await tester.pumpAndSettle();
      expect(AppPreferencesService.hapticsEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ems.pref.hapticsEnabled'), isFalse);

      await tester.ensureVisible(find.text('Storage & Cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Storage & Cache'));
      await tester.pumpAndSettle();
      expect(find.byType(StorageCacheScreen), findsOneWidget);
      expect(find.text('Image Memory Cache'), findsWidgets);
      expect(find.text('Temp Camera Photos'), findsWidgets);
      expect(find.text('PDF & Documents'), findsWidgets);
      expect(find.text('Other Temp Files'), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('storage-clear-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('storage-clear-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-clear-cache-dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-clear-cache-button')));
      await tester.pumpAndSettle();
      expect(find.byType(StorageCacheScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(StorageCacheScreen))).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Device & Connection Check'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device & Connection Check'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceCheckScreen), findsOneWidget);
      expect(find.text('EMS Server'), findsOneWidget);
      expect(find.text('Location (GPS)'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
    },
  );

  testWidgets(
    'Switch Account sheet caps at 3 recent accounts and opens SavedAccountsScreen for all',
    (tester) async {
      final now = DateTime.now().toIso8601String();
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({
          'id': 'emp-1',
          'username': 'user1',
          'name': 'Account One',
        }),
        'ems.authToken': 'mock-token',
        'ems.recentAccounts': jsonEncode([
          {'username': 'user1', 'name': 'Account One', 'lastUsedAt': now},
          {'username': 'user2', 'name': 'Account Two', 'lastUsedAt': now},
          {'username': 'user3', 'name': 'Account Three', 'lastUsedAt': now},
          {'username': 'user4', 'name': 'Account Four', 'lastUsedAt': now},
        ]),
      });
      AuthService.debugOverrideClient(
        MockClient((_) async {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'emp-1',
                'username': 'user1',
                'name': 'Account One',
              },
              'roles': ['Staff'],
            }),
            200,
          );
        }),
      );
      addTearDown(AuthService.debugResetClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forMode(AppThemeMode.defaultTheme),
          home: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final switchBtn = find.byKey(const Key('switch-account-button'));
      await tester.ensureVisible(switchBtn);
      await tester.pumpAndSettle();
      await tester.tap(switchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Account One'), findsWidgets);
      expect(find.text('Account Two'), findsOneWidget);
      expect(find.text('Account Three'), findsOneWidget);
      expect(find.text('Account Four'), findsNothing);

      final viewAllBtn = find.byKey(
        const Key('view-all-switched-accounts-button'),
      );
      expect(viewAllBtn, findsOneWidget);
      await tester.tap(viewAllBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SavedAccountsScreen), findsOneWidget);
      expect(find.text('Account Four'), findsOneWidget);
    },
  );

  testWidgets('SettingsScreen opens HelpFaqScreen and toggles FAQ accordion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await LanguageService.setLanguage(AppLanguage.en);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forMode(AppThemeMode.defaultTheme),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final helpTile = find.byKey(const Key('settings-help-faq-tile'));
    await tester.ensureVisible(helpTile);
    await tester.pumpAndSettle();
    await tester.tap(helpTile);
    await tester.pumpAndSettle();

    expect(find.text('Help & Guide'), findsOneWidget);
    expect(find.text('Cirrus EMS Quick Guide'), findsOneWidget);

    // Starts collapsed; tap item 0 to expand, tap again to collapse.
    expect(find.textContaining('auto-sync every 15 seconds'), findsNothing);
    await tester.tap(find.byKey(const Key('help-faq-item-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('auto-sync every 15 seconds'), findsOneWidget);

    await tester.tap(find.byKey(const Key('help-faq-item-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('auto-sync every 15 seconds'), findsNothing);
  });
}
