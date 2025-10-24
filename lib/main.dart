import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
// import 'dart:convert'; // Unused import
import 'package:move_young/screens/welcome/welcome_screen.dart';
import 'package:move_young/theme/_theme.dart';
// import 'package:move_young/services/haptics_service.dart';
import 'package:move_young/services/accessibility_service.dart';
import 'package:move_young/widgets/sync_status_indicator.dart';
// import 'package:move_young/screens/main_scaffold.dart'; // Unused import
import 'firebase_options.dart';
import 'package:move_young/utils/logger.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global timer reference for cache cleanup to prevent memory leaks
Timer? _cacheCleanupTimer;

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
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Services are now initialized through Riverpod providers
  // This ensures proper dependency injection and testability
  // Haptics and Accessibility will be initialized when first accessed
  // to avoid SharedPreferences channel errors during app startup

  // Schedule periodic cache cleanup every 6 hours
  _cacheCleanupTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
    try {
      // Cache cleanup will be handled through providers
      // await CacheService.clearExpiredCache();
    } catch (_) {}
  });

  // Status bar styling only; avoid forcing Android nav bar appearance
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('nl')],
        path: 'assets/translations',
        fallbackLocale: const Locale('nl'),
        startLocale: const Locale('nl'),
        child: const MoveYoungApp(),
      ),
    ),
  );
}

class MoveYoungApp extends StatefulWidget {
  const MoveYoungApp({super.key});

  @override
  State<MoveYoungApp> createState() => _MoveYoungAppState();
}

class _MoveYoungAppState extends State<MoveYoungApp>
    with WidgetsBindingObserver {
  bool _highContrast = false;
  StreamSubscription<bool>? _highContrastSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer SharedPreferences access until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHighContrastSetting();
      _listenToHighContrastChanges();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _highContrastSubscription?.cancel();
    // Cancel the global cache cleanup timer to prevent memory leaks
    _cacheCleanupTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      // Cancel timer when app is being closed
      _cacheCleanupTimer?.cancel();
    }
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
      navigatorKey: navigatorKey,
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
      home: GlobalSyncStatusBanner(
        child: const WelcomeScreen(),
      ),
    );
  }
}

// Removed unused notification handlers - kept for reference if needed later

// Removed unused navigation methods - kept for reference if needed later

// Global variables for pending navigation
// String? _pendingGameId; // Removed unused variable

// Background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
  // Handle background messages here
}
