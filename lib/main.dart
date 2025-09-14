import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:move_young/screens/welcome/welcome_screen.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    // ignore: avoid_print
    print('Firebase initialized successfully');
  } catch (e) {
    // Firebase initialization failed
    // ignore: avoid_print
    print('Firebase init failed: $e');
  }

  // Initialize Firebase App Check
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
      webProvider: ReCaptchaV3Provider('auto'),
    );
  } catch (e) {
    // App Check initialization failed; safe to proceed in dev
  }

  // Notifications
  try {
    await NotificationService.initialize();
  } catch (_) {}

  // Status bar styling only; avoid forcing Android nav bar appearance
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('nl')],
      path: 'assets/translations',
      fallbackLocale: const Locale('nl'),
      startLocale: const Locale('nl'),
      child: const MoveYoungApp(),
    ),
  );
}

class MoveYoungApp extends StatelessWidget {
  const MoveYoungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoveYoung',
      theme: AppTheme.minimal().copyWith(
        // Ensure nav bar never gets tinted pink
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          elevation: 8,
          selectedItemColor: Color(0xFF0077B6),
          unselectedItemColor: Color(0xFF5C677D),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent, // <- kill Material3 tint
        ),
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      scrollBehavior: AppScrollBehavior(),
      home: const WelcomeScreen(),
    );
  }
}
