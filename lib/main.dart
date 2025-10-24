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
import 'package:move_young/services/connectivity_service.dart';
import 'package:move_young/services/sync_service.dart';
import 'package:move_young/services/image_cache_service.dart';
import 'package:move_young/services/cache_service.dart';
import 'package:move_young/widgets/sync_status_indicator.dart';
import 'package:move_young/screens/main_scaffold.dart';
import 'firebase_options.dart';
import 'package:move_young/utils/logger.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      onDeepLinkNavigation: _handleDeepLinkNavigation,
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

  // Connectivity monitoring
  try {
    await ConnectivityService.initialize();
  } catch (_) {}

  // Sync service
  try {
    await SyncService.initialize();
  } catch (_) {}

  // Image cache service
  try {
    await ImageCacheService.initialize();
  } catch (_) {}

  // Cache service cleanup
  try {
    await CacheService.clearExpiredCache();
    // Schedule periodic cache cleanup every 6 hours
    Timer.periodic(const Duration(hours: 6), (timer) async {
      try {
        await CacheService.clearExpiredCache();
      } catch (_) {}
    });
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

// Handle notification taps and navigate to appropriate screen
void _handleNotificationTap(String? payload) {
  if (payload == null) return;

  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final type = data['type'] as String?;
    final route = data['route'] as String?;
    final gameId = data['gameId'] as String?;

    debugPrint('Notification tapped: $type -> $route, gameId: $gameId');

    // Handle game invite notifications
    if (type == 'game_invite' && gameId != null) {
      _navigateToGame(gameId);
    }
  } catch (e) {
    debugPrint('Error handling notification tap: $e');
  }
}

// Handle deep link navigation from notifications
void _handleDeepLinkNavigation(Map<String, dynamic> data) {
  debugPrint('Deep link navigation: $data');

  final type = data['type'] as String?;
  final gameId = data['gameId'] as String?;

  if (type == 'game_invite' && gameId != null) {
    // Navigate to games tab and highlight the specific game
    _navigateToGame(gameId);
  }
}

// Navigate to specific game
void _navigateToGame(String gameId) {
  debugPrint('Navigating to game: $gameId');

  // Try to navigate immediately if the app is already running
  _tryNavigateToGame(gameId);
}

// Try to navigate to game using the current scaffold controller
void _tryNavigateToGame(String gameId) {
  debugPrint('Attempting to navigate to game: $gameId');

  // Get the current context from the global navigator
  final context = navigatorKey.currentContext;
  if (context == null) {
    debugPrint('No context available for navigation');
    return;
  }

  // Try to find the MainScaffoldController in the widget tree
  final controller = MainScaffoldController.maybeOf(context);
  if (controller != null) {
    debugPrint('Found MainScaffoldController, navigating to game: $gameId');
    controller.openMyGames(
      initialTab: 0, // Joining tab
      highlightGameId: gameId,
      popToRoot: true,
    );
  } else {
    debugPrint(
        'MainScaffoldController not found, cannot navigate to game: $gameId');
  }
}

// Global variables for pending navigation
// String? _pendingGameId; // Removed unused variable
