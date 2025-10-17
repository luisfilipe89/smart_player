import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:convert';
import 'package:move_young/screens/welcome/welcome_screen.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/notification_service.dart';
import 'package:move_young/services/haptics_service.dart';
import 'package:move_young/services/accessibility_service.dart';
import 'firebase_options.dart';
import 'package:move_young/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NumberedLogger.install();
  await EasyLocalization.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Firebase initialized successfully
  } catch (e) {
    // Firebase initialization failed
    // Firebase init failed: $e
  }

  // Initialize Firebase App Check (optional for development)
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
      webProvider: ReCaptchaV3Provider('auto'),
    );
  } catch (e) {
    // App Check initialization failed; safe to proceed in dev
  }

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Notifications
  try {
    await NotificationService.initialize(
      onNotificationTap: _handleNotificationTap,
    );
  } catch (_) {}

  // Haptics (load persisted preference)
  try {
    await HapticsService.initialize();
  } catch (_) {}

  // Accessibility (load persisted preference)
  try {
    await AccessibilityService.initialize();
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

class MoveYoungApp extends StatefulWidget {
  const MoveYoungApp({super.key});

  @override
  State<MoveYoungApp> createState() => _MoveYoungAppState();
}

class _MoveYoungAppState extends State<MoveYoungApp> {
  bool _highContrast = false;
  StreamSubscription<bool>? _highContrastSubscription;

  @override
  void initState() {
    super.initState();
    _loadHighContrastSetting();
    _listenToHighContrastChanges();
  }

  @override
  void dispose() {
    _highContrastSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadHighContrastSetting() async {
    final isHighContrast = await AccessibilityService.isHighContrastEnabled();
    if (mounted) {
      setState(() {
        _highContrast = isHighContrast;
      });
    }
  }

  void _listenToHighContrastChanges() {
    _highContrastSubscription =
        AccessibilityService.highContrastStream().listen((isHighContrast) {
      if (mounted) {
        setState(() {
          _highContrast = isHighContrast;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoveYoung',
      theme: _highContrast
          ? AppTheme.highContrast()
          : AppTheme.minimal().copyWith(
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

// Handle notification taps and navigate to appropriate screen
void _handleNotificationTap(String? payload) {
  if (payload == null) return;

  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final type = data['type'] as String?;
    final route = data['route'] as String?;

    // Store the notification data for navigation when app is ready
    // This will be handled by the main scaffold when it's available
    debugPrint('Notification tapped: $type -> $route');

    // For now, just log the notification data
    // In a real implementation, you'd navigate to the appropriate screen
    // based on the notification type and route
  } catch (e) {
    debugPrint('Error handling notification tap: $e');
  }
}
