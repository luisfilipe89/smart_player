import 'package:diacritic/diacritic.dart';

class Profanity {
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

  static final List<String> _blocklist =
      {..._en, ..._nl}.map((w) => w.toLowerCase()).toList();

  static bool isNameAllowed(String name) {
    final normalized = _normalize(name);
    if (_containsBlocked(normalized)) return false;
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    for (final t in tokens) {
      if (_containsBlocked(t)) return false;
    }
    return true;
  }

  static bool _containsBlocked(String text) {
    for (final bad in _blocklist) {
      if (text.contains(bad)) return true;
    }
    return false;
  }

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
