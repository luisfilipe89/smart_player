import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';

const String _kLocalePrefKey = 'app_locale_code';

class LocaleController {
  LocaleController(this._prefs);

  final SharedPreferences? _prefs;

  Future<String?> loadSavedLocaleCode() async {
    try {
      return _prefs?.getString(_kLocalePrefKey);
    } catch (e) {
      debugPrint('LocaleController: loadSavedLocaleCode error: $e');
      return null;
    }
  }

  Future<void> saveLocale(Locale locale) async {
    try {
      await _prefs?.setString(_kLocalePrefKey, locale.languageCode);
    } catch (e) {
      debugPrint('LocaleController: saveLocale error: $e');
    }
  }

  Locale? parseLocaleCode(String? code) {
    if (code == null || code.isEmpty) return null;
    switch (code) {
      case 'en':
      case 'nl':
        return Locale(code);
      default:
        return null;
    }
  }
}

final localeControllerProvider = Provider<LocaleController>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  // Use valueOrNull to get SharedPreferences if available, null otherwise
  final prefs = prefsAsync.valueOrNull;
  return LocaleController(prefs);
});
