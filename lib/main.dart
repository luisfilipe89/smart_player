import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:move_young/screens/welcome/welcome_screen.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/system/accessibility_provider.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';
import 'package:move_young/widgets/common/sync_status_indicator.dart';
import 'firebase_options.dart';
import 'package:move_young/utils/logger.dart';

// Global navigator key for navigation from notifications
// Note: This is still needed for Firebase notification callbacks in background
// as they don't have access to the provider context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Handle errors in async Zone
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    NumberedLogger.install();

    // SharedPreferences will be initialized after first frame
    // to avoid platform channel errors during app startup

    // Handle errors gracefully
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log platform channel errors but don't crash the app
      if (details.exception is PlatformException) {
        final error = details.exception as PlatformException;
        if (error.code == 'channel-error') {
          debugPrint('Platform channel error (ignored): ${error.message}');
          return;
        }
      }
      // Let other errors be handled normally
      FlutterError.presentError(details);
    };

    // Defer EasyLocalization initialization; the widget will handle loading

    // Services are now initialized through Riverpod providers
    // This ensures proper dependency injection and testability
    // Haptics and Accessibility will be initialized when first accessed
    // to avoid SharedPreferences channel errors during app startup

    // Status bar styling only; avoid forcing Android nav bar appearance
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    // Render the first frame ASAP
    runApp(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('nl')],
          path: 'assets/translations',
          fallbackLocale: const Locale('nl'),
          startLocale: const Locale('nl'),
          saveLocale: false,
          child: const MoveYoungApp(),
        ),
      ),
    );

    // Kick off heavy init work asynchronously (do not block first frame)
    // Firebase init
    unawaited(Future(() async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {}

      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
          webProvider: ReCaptchaV3Provider('auto'),
        );
      } catch (_) {}

      // Initialize Crashlytics
      try {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);
        FlutterError.onError = (errorDetails) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        };
      } catch (_) {}

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }));
  }, (error, stack) {
    // Handle uncaught errors gracefully
    debugPrint('Uncaught error in main: $error');
    if (error is PlatformException && error.code == 'channel-error') {
      debugPrint('Ignoring platform channel error during startup');
      return;
    }
    // Re-throw other errors
    throw error;
  });
}

class MoveYoungApp extends ConsumerStatefulWidget {
  const MoveYoungApp({super.key});

  @override
  ConsumerState<MoveYoungApp> createState() => _MoveYoungAppState();
}

class _MoveYoungAppState extends ConsumerState<MoveYoungApp>
    with WidgetsBindingObserver {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wait a full frame cycle before initializing
    // This ensures platform channels are completely ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize SharedPreferences after first frame
      if (mounted) {
        await initializeSharedPreferences(ref);
      }
      // Wait another frame to be extra safe
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // didChangeAppLifecycleState removed - not needed currently

  @override
  Widget build(BuildContext context) {
    // First build: show provider-free MaterialApp
    if (!_isInitialized) {
      debugPrint('[Bootstrap] Rendering first frame Splash');
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    // Second build: use providers
    return Consumer(
      builder: (context, ref, child) {
        // Try to get high contrast mode, but don't block on it
        bool isHighContrast = false;
        try {
          isHighContrast = ref.watch(isHighContrastEnabledProvider);
        } catch (e) {
          debugPrint('Error reading high contrast mode: $e');
          isHighContrast = false;
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'MoveYoung',
          theme: isHighContrast
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
                    surfaceTintColor:
                        Colors.transparent, // <- kill Material3 tint
                  ),
                ),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          scrollBehavior: AppScrollBehavior(),
          home: const WelcomeScreenWrapper(),
        );
      },
    );
  }
}

/// Simple splash screen that doesn't use any providers
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Wrapper widget for WelcomeScreen that includes GlobalSyncStatusBanner
/// This wrapper defers GlobalSyncStatusBanner initialization to avoid platform channel errors
class WelcomeScreenWrapper extends StatefulWidget {
  const WelcomeScreenWrapper({super.key});

  @override
  State<WelcomeScreenWrapper> createState() => _WelcomeScreenWrapperState();
}

class _WelcomeScreenWrapperState extends State<WelcomeScreenWrapper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Defer GlobalSyncStatusBanner initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const WelcomeScreen();
    }
    return GlobalSyncStatusBanner(
      child: const WelcomeScreen(),
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
