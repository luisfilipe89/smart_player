import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// No explicit DartPluginRegistrant import; rely on default plugin registration
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:move_young/screens/welcome/welcome_screen.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/system/accessibility_provider.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';
import 'package:move_young/providers/locale_controller.dart';
import 'package:move_young/widgets/common/sync_status_indicator.dart';
import 'firebase_options.dart';
import 'package:move_young/config/app_bootstrap.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/services/notifications/notification_provider.dart';

// Global navigator key for navigation from notifications
// Note: This is still needed for Firebase notification callbacks in background
// as they don't have access to the provider context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Handle errors in async Zone
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      NumberedLogger.install();

      // Centralized bootstrap for Firebase, AppCheck, Crashlytics, and BG messaging
      await AppBootstrap.initialize();

      // SharedPreferences will be initialized after first frame
      // to avoid platform channel errors during app startup

      // Handle errors gracefully and report to Crashlytics when available
      FlutterError.onError = (FlutterErrorDetails details) {
        // Filter platform channel noise
        if (details.exception is PlatformException) {
          final error = details.exception as PlatformException;
          if (error.code == 'channel-error') {
            debugPrint('Platform channel error (ignored): ${error.message}');
            return;
          }
        }
        // Ignore legacy SQLite noise
        final exceptionText = details.exception.toString();
        if (exceptionText.contains('sqflite') ||
            exceptionText.contains('getDatabasesPath')) {
          return;
        }

        // Present error to default handler
        FlutterError.presentError(details);

        // Best-effort Crashlytics reporting without assuming initialization order
        try {
          // Use fatal for framework-level errors
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } catch (_) {
          // Crashlytics not ready; ignore
        }
      };

      // Defer EasyLocalization initialization; the widget will handle loading

      // Services are now initialized through Riverpod providers
      // This ensures proper dependency injection and testability
      // Haptics and Accessibility will be initialized when first accessed
      // to avoid SharedPreferences channel errors during app startup

      // Status bar styling only; avoid forcing Android nav bar appearance
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      // Do not block startup on EasyLocalization internal init. We handle
      // locale persistence ourselves post-runApp to avoid channel races.
      debugPrint('[Startup] Skipping EasyLocalization.ensureInitialized()');

      // Render the first frame ASAP
      runApp(
        ProviderScope(
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nl')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            // Do not force a startLocale if a saved value exists; we manage persistence ourselves
            saveLocale: false, // We handle persistence via LocaleController
            useOnlyLangCode: true, // Use only language code (en, nl)
            child: const MoveYoungApp(),
          ),
        ),
      );

      // AppCheck and Crashlytics are initialized by AppBootstrap
    },
    (error, stack) {
      // Handle uncaught errors gracefully
      debugPrint('Uncaught error in main: $error');
      if (error is PlatformException && error.code == 'channel-error') {
        debugPrint('Ignoring platform channel error during startup');
        return;
      }
      // Ignore any remaining SQLite errors (no longer used)
      if (error.toString().contains('sqflite') ||
          error.toString().contains('MissingPluginException')) {
        debugPrint('Ignoring SQLite-related error (no longer used)');
        return;
      }
      // Best-effort Crashlytics reporting for uncaught async errors
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {}
      // Re-throw other errors
      throw error;
    },
  );
}

class MoveYoungApp extends ConsumerStatefulWidget {
  const MoveYoungApp({super.key});

  @override
  ConsumerState<MoveYoungApp> createState() => _MoveYoungAppState();
}

class _MoveYoungAppState extends ConsumerState<MoveYoungApp>
    with WidgetsBindingObserver {
  bool _isInitialized = false;
  ProviderSubscription? _prefsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Apply saved locale when SharedPreferences becomes available later
    _prefsSubscription = ref.listenManual(sharedPreferencesProvider, (
      previous,
      next,
    ) async {
      if (previous == null && next != null && mounted && context.mounted) {
        try {
          final ctrl = ref.read(localeControllerProvider);
          final saved = await ctrl.loadSavedLocaleCode();
          final locale = ctrl.parseLocaleCode(saved);
          if (locale != null) {
            await context.setLocale(locale);
            debugPrint(
              '[Startup] Applied saved locale on prefs ready: ${locale.languageCode}',
            );
          }
        } catch (e) {
          debugPrint('Failed to apply saved locale (late): $e');
        }
      }
    });
    // Wait a full frame cycle before initializing
    // This ensures platform channels are completely ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize SharedPreferences after first frame
      if (mounted) {
        try {
          await initializeSharedPreferences(
            ref,
          ).timeout(const Duration(seconds: 2));
          debugPrint('[Startup] SharedPreferences init completed');
        } catch (e) {
          debugPrint(
            '[Startup] SharedPreferences init timed out or failed: $e',
          );
        }
        // Apply saved locale after SharedPreferences is ready
        try {
          final ctrl = ref.read(localeControllerProvider);
          final saved = await ctrl.loadSavedLocaleCode();
          final locale = ctrl.parseLocaleCode(saved);
          if (locale != null && mounted && context.mounted) {
            await context.setLocale(locale);
            debugPrint(
              '[Startup] Applied saved locale after init: ${locale.languageCode}',
            );
          }
        } catch (e) {
          debugPrint('Failed to apply saved locale: $e');
        }
        // Mark as initialized after SharedPreferences is ready
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _prefsSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // didChangeAppLifecycleState removed - not needed currently

  @override
  Widget build(BuildContext context) {
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

        // Initialize notifications with deep-link dispatcher once after init
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final dispatcher = ref.read(deepLinkDispatcherProvider);
            await ref
                .read(notificationActionsProvider)
                .initialize(onDeepLinkNavigation: dispatcher.dispatch);
          } catch (_) {}
        });

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'MoveYoung',
          theme: isHighContrast
              ? AppTheme.highContrast()
              : AppTheme.minimal().copyWith(
                  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                    backgroundColor: AppColors.white,
                    elevation: 8,
                    selectedItemColor: Color(0xFF0077B6),
                    unselectedItemColor: Color(0xFF5C677D),
                  ),
                  navigationBarTheme: const NavigationBarThemeData(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                  ),
                ),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          scrollBehavior: AppScrollBehavior(),
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: _isInitialized
                ? const WelcomeScreenWrapper(key: ValueKey('welcome'))
                : const ModernSplashScreen(key: ValueKey('splash')),
          ),
        );
      },
    );
  }
}

class ModernSplashScreen extends StatelessWidget {
  const ModernSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.95, end: 1.0),
          builder: (context, scale, child) {
            final t = ((scale - 0.95) / 0.05).clamp(0.0, 1.0);
            return Opacity(
              opacity: t,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text('MoveYoung', style: AppTextStyles.h3),
              const SizedBox(height: 24),
              SizedBox(
                width: 140,
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: AppColors.superlightgrey,
                ),
              ),
            ],
          ),
        ),
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
    return GlobalSyncStatusBanner(child: const WelcomeScreen());
  }
}

// Removed unused notification handlers - kept for reference if needed later

// Removed unused navigation methods - kept for reference if needed later

// Global variables for pending navigation
// String? _pendingGameId; // Removed unused variable

// Background message handler for Firebase Messaging
// Note: This runs in a separate isolate, so it can't access platform channels
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase for background isolate
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}

    debugPrint('Background message received: ${message.messageId}');
  } catch (e) {
    // Suppress errors from plugin initialization in background isolate
    // (SharedPreferences, SQLite, etc. aren't available in background threads)
    debugPrint('Background message handler error (suppressed): $e');
  }
}
