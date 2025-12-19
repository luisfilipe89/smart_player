import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart';
// No explicit DartPluginRegistrant import; rely on default plugin registration
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:move_young/features/welcome/screens/welcome_screen.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/system/accessibility_provider.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart'
    show initializeSharedPreferencesEarly, sharedPreferencesProvider;
import 'package:move_young/providers/locale_controller.dart';
import 'package:move_young/widgets/sync_status_indicator.dart';
import 'package:move_young/firebase_options.dart';
import 'package:move_young/config/app_bootstrap.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/services/notifications/notification_provider.dart';
import 'package:move_young/services/calendar/calendar_sync_service.dart';
import 'package:move_young/services/system/sync_provider.dart';
import 'package:move_young/features/agenda/services/cached_events_provider.dart';
import 'package:move_young/services/system/notification_settings_provider.dart';

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

      // Register background message handler BEFORE Firebase initialization
      // This must be a top-level function and registered early (Firebase requirement)
      // However, the actual background FlutterEngine creation is deferred
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Only initialize critical Firebase services synchronously
      // Non-critical services (AppCheck, Analytics) will be deferred
      await AppBootstrap.initialize();

      // Initialize SharedPreferences EARLY in main() before runApp()
      // This ensures platform channels are ready and plugin is registered
      // Start initialization but don't block - it will complete asynchronously
      // The FutureProvider will use the early-initialized instance when ready
      initializeSharedPreferencesEarly();

      // Set up global error widget builder for widget build-time errors
      // This catches errors that occur during widget build, preventing app crashes
      ErrorWidget.builder = (FlutterErrorDetails details) {
        NumberedLogger.e('Widget build error: ${details.exception}');
        NumberedLogger.d('Stack: ${details.stack}');

        // Report to Crashlytics in production
        if (kReleaseMode) {
          try {
            FirebaseCrashlytics.instance.recordError(
              details.exception,
              details.stack,
              reason: 'Widget build error',
              fatal: false,
            );
          } catch (_) {
            // Crashlytics not ready; ignore
          }
        }

        // Return a safe error widget instead of crashing
        // Note: We can't use translations here as EasyLocalization may not be initialized
        return Material(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong while displaying this content.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      };

      // Handle errors gracefully and report to Crashlytics when available
      FlutterError.onError = (FlutterErrorDetails details) {
        // Filter platform channel noise
        if (details.exception is PlatformException) {
          final error = details.exception as PlatformException;
          if (error.code == 'channel-error') {
            NumberedLogger.d(
                'Platform channel error (ignored): ${error.message}');
            return;
          }
        }
        // Ignore SQLite plugin errors during startup (calendar database uses sqflite)
        // Only ignore if it's a missing plugin exception (package not installed yet)
        final exceptionText = details.exception.toString();
        if (exceptionText.contains('MissingPluginException') &&
            exceptionText.contains('sqflite')) {
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
      NumberedLogger.d(
          '[Startup] Skipping EasyLocalization.ensureInitialized()');

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
      NumberedLogger.e('Uncaught error in main: $error');
      if (error is PlatformException && error.code == 'channel-error') {
        NumberedLogger.d('Ignoring platform channel error during startup');
        return;
      }
      // Ignore SQLite errors from calendar database (it's intentionally used for calendar tracking)
      // Only ignore if it's a missing plugin exception (package not installed yet)
      if (error.toString().contains('MissingPluginException') &&
          error.toString().contains('sqflite')) {
        NumberedLogger.d(
            'Ignoring SQLite plugin error (package may not be installed yet)');
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
  bool _notificationServiceInitialized =
      false; // Guard to prevent multiple notification initializations
  bool _syncServiceInitialized =
      false; // Guard to prevent multiple sync service initializations
  ProviderSubscription? _prefsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Apply saved locale when SharedPreferences becomes available
    // FutureProvider handles initialization automatically, no manual call needed
    _prefsSubscription = ref.listenManual(sharedPreferencesProvider, (
      previous,
      next,
    ) async {
      // When SharedPreferences transitions from loading to data, apply saved locale
      final wasLoading = previous?.isLoading ?? true;
      final hasData = next?.hasValue ?? false;

      if (wasLoading && hasData && mounted && context.mounted) {
        try {
          final ctrl = ref.read(localeControllerProvider);
          final saved = await ctrl.loadSavedLocaleCode();
          final locale = ctrl.parseLocaleCode(saved);
          if (locale != null && mounted && context.mounted) {
            await context.setLocale(locale);
            NumberedLogger.i(
              '[Startup] Applied saved locale on prefs ready: ${locale.languageCode}',
            );
          }
        } catch (e) {
          NumberedLogger.w('Failed to apply saved locale (late): $e');
        }
      }
    });

    // Wait a full frame cycle before marking as initialized
    // This ensures platform channels are completely ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Initialize non-critical Firebase services (AppCheck, Analytics)
      // This avoids blocking the first frame with non-critical initialization
      unawaited(AppBootstrap.initializeDeferred().catchError((e) {
        NumberedLogger.e('Deferred initialization failed: $e');
      }));

      // After first frame, ensure SharedPreferences initialization is attempted
      // The early initialization started in main() should complete by now
      // FutureProvider will use that instance if available
      NumberedLogger.d(
          '[Startup] After first frame - SharedPreferences should be initializing');

      // Give SharedPreferences a moment to initialize after first frame
      // This ensures plugin registration is definitely complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Mark as initialized - SharedPreferences will be available when ready
      // Consumers handle loading/error states appropriately
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
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
        // Use read() instead of watch() to avoid reactive rebuilds during startup
        // and handle null gracefully
        bool isHighContrast = false;
        try {
          // Check if SharedPreferences is available (FutureProvider may still be loading)
          final prefsAsync = ref.read(sharedPreferencesProvider);
          if (prefsAsync.hasValue) {
            isHighContrast = ref.read(isHighContrastEnabledProvider);
          }
        } catch (e) {
          // Silently use default - high contrast is optional
          isHighContrast = false;
        }

        // Initialize notifications with deep-link dispatcher after app is fully loaded
        // Defer significantly to avoid blocking UI during startup
        // Permission requests will happen after user sees the app
        // Only initialize once (build() can be called multiple times)
        if (!_notificationServiceInitialized) {
          _notificationServiceInitialized = true;
          Future.delayed(const Duration(seconds: 2), () async {
            if (!mounted) return;
            try {
              final dispatcher = ref.read(deepLinkDispatcherProvider);
              // Initialize without blocking - permission requests are now non-blocking
              unawaited(ref
                  .read(notificationActionsProvider)
                  .initialize(onDeepLinkNavigation: dispatcher.dispatch)
                  .catchError((e) {
                NumberedLogger.e('Notification initialization error: $e');
              }));
            } catch (e) {
              NumberedLogger.e(
                  'Notification initialization error (non-critical): $e');
            }
          });
        }

        // Watch calendar sync provider to automatically sync calendar events
        // This provider watches matches and syncs calendar events when matches change
        ref.watch(calendarSyncProvider);

        // Watch events preload provider to preload events in background when user logs in
        ref.watch(eventsPreloadProvider);

        // Initialize sync service after SharedPreferences is ready
        // Only initialize once (build() can be called multiple times)
        if (!_syncServiceInitialized) {
          _syncServiceInitialized = true;
          // Use microtask to ensure initialization happens after first frame
          // but before the delayed execution, giving SharedPreferences time to initialize
          Future.microtask(() async {
            // Small delay to ensure SharedPreferences is ready
            await Future.delayed(const Duration(milliseconds: 500));
            if (!mounted) return;
            try {
              final syncActions = ref.read(syncActionsProvider);
              if (syncActions != null) {
                await syncActions.initialize();
                NumberedLogger.i('Sync service initialized');
              } else {
                NumberedLogger.w(
                    'Sync service not available (SharedPreferences may not be ready)');
              }
            } catch (e, stack) {
              NumberedLogger.w(
                  'Sync service initialization error (non-critical): $e');
              NumberedLogger.d('Stack trace: $stack');
            }
          });
        }

        // Initialize notification settings service after SharedPreferences is ready
        // This ensures preferences are loaded early
        final notificationSettingsActions =
            ref.read(notificationSettingsActionsProvider);
        if (notificationSettingsActions != null) {
          // Initialize asynchronously without blocking
          Future.microtask(() async {
            try {
              await notificationSettingsActions.initialize();
              NumberedLogger.d('Notification settings initialized');
            } catch (e) {
              NumberedLogger.w(
                  'Notification settings initialization error (non-critical): $e');
            }
          });
        }

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
                  color: AppColors.primary.withValues(alpha: 0.08),
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

    NumberedLogger.d('Background message received: ${message.messageId}');
  } catch (e) {
    // Suppress errors from plugin initialization in background isolate
    // (SharedPreferences, SQLite, etc. aren't available in background threads)
    NumberedLogger.e('Background message handler error (suppressed): $e');
  }
}
