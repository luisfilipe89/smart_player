import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesService {
  static const _key = 'favorite_locations';

  static Future<Set<String>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString == null) return {};
      return Set<String>.from(json.decode(jsonString));
    } catch (e) {
      return {};
    }
  }

  static Future<void> toggleFavorite(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getFavorites();
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
      await prefs.setString(_key, json.encode(current.toList()));
    } catch (e) {
      // If SharedPreferences fails, silently ignore
    }
  }

  static Future<bool> isFavorite(String id) async {
    final current = await getFavorites();
    return current.contains(id);
  }
}
