import 'package:diacritic/diacritic.dart';

/// Utility class for profanity filtering in user names and content.
///
/// Provides methods to check if a name contains profanity in English or Dutch.
/// Uses normalization to detect attempts to bypass filters (e.g., using
/// numbers, special characters, or diacritics).
class Profanity {
  // English profanity blocklist
  static final List<String> _en = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'bastard',
    'dick',
    'cunt',
    'slut',
    'whore',
    'nigger',
    'faggot',
    'retard'
  ];

  // Dutch profanity blocklist
  static final List<String> _nl = [
    'kanker',
    'tyfus',
    'tering',
    'lul',
    'kut',
    'sukkel',
    'eikel',
    'mogool',
    'homo',
    'hoer'
  ];

  // Combined blocklist (normalized to lowercase)
  static final List<String> _blocklist =
      {..._en, ..._nl}.map((w) => w.toLowerCase()).toList();

  /// Checks if a name is allowed (does not contain profanity).
  ///
  /// The name is normalized (diacritics removed, special characters replaced,
  /// non-alphabetic characters removed) and checked against the blocklist.
  /// Also checks individual tokens (words) in the name.
  ///
  /// Returns `true` if the name is allowed, `false` if it contains profanity.
  static bool isNameAllowed(String name) {
    final normalized = _normalize(name);
    if (_containsBlocked(normalized)) return false;
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    for (final t in tokens) {
      if (_containsBlocked(t)) return false;
    }
    return true;
  }

  /// Checks if the text contains any blocked words.
  static bool _containsBlocked(String text) {
    for (final bad in _blocklist) {
      if (text.contains(bad)) return true;
    }
    return false;
  }

  /// Normalizes input text to detect bypass attempts.
  ///
  /// Performs the following transformations:
  /// - Converts to lowercase
  /// - Removes diacritics (é -> e, ñ -> n, etc.)
  /// - Replaces common character substitutions (@ -> a, $ -> s, 0 -> o, etc.)
  /// - Removes all non-alphabetic characters
  static String _normalize(String input) {
    String s = input.toLowerCase();
    s = removeDiacritics(s);
    s = s
        .replaceAll('@', 'a')
        .replaceAll('\$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't');
    s = s.replaceAll(RegExp(r'[^a-z]'), '');
    return s;
  }
}
