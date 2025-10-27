import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashlyticsHelper {
  static void breadcrumb(String message) {
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  static void recordError(dynamic error, StackTrace stack,
      {String? reason, bool fatal = false}) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack,
          reason: reason, fatal: fatal);
    } catch (_) {}
  }
}


