import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/app_preferences_service.dart';
import 'services/biometric_service.dart';
import 'services/language_service.dart';
import 'services/shift_reminder_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Align touch/scroll sampling with 60Hz/90Hz/120Hz VSync to remove drag jitter,
  // and cap image cache at 64 MB to prevent GC stalls on 2-4GB budget phones.
  GestureBinding.instance.resamplingEnabled = true;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 * 1024 * 1024;

  await Future.wait([
    dotenv.load(fileName: '.env'),
    ThemeService.init(),
    LanguageService.init(),
    AppPreferencesService.init(),
    BiometricService.init(),
    ShiftReminderService.init(),
  ]);

  runApp(const MyApp());
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.themeModeNotifier,
        ThemeService.textScaleNotifier,
        LanguageService.languageNotifier,
      ]),
      builder: (context, _) {
        final isThai = LanguageService.currentLanguage == AppLanguage.th;
        final scaleFactor =
            ThemeService.currentTextScale.factor * (isThai ? 0.93 : 1.0);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Cirrus EMS',
          scrollBehavior: const _NoStretchScrollBehavior(),
          themeAnimationDuration: const Duration(milliseconds: 260),
          themeAnimationCurve: Curves.easeOutCubic,
          theme: AppTheme.forMode(
            ThemeService.currentMode,
            language: LanguageService.currentLanguage,
          ),
          builder: (context, child) {
            if (child == null || scaleFactor == 1.0) {
              return child ?? const SizedBox.shrink();
            }
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(scaleFactor),
              ),
              child: child,
            );
          },
          home: const SplashScreen(
            minDisplayDuration: Duration(milliseconds: 1250),
          ),
        );
      },
    );
  }
}
