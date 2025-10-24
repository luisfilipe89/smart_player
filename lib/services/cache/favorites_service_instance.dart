import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesServiceInstance {
  final SharedPreferences _prefs;
  static const _key = 'favorite_locations';

  FavoritesServiceInstance(this._prefs);

  Future<Set<String>> getFavorites() async {
    try {
      final jsonString = _prefs.getString(_key);
      if (jsonString == null) return {};
      return Set<String>.from(json.decode(jsonString));
    } catch (e) {
      return {};
    }
  }

  Future<void> toggleFavorite(String id) async {
    try {
      final current = await getFavorites();
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
      await _prefs.setString(_key, json.encode(current.toList()));
    } catch (e) {
      // If SharedPreferences fails, silently ignore
    }
  }

  Future<bool> isFavorite(String id) async {
    final current = await getFavorites();
    return current.contains(id);
  }
}
