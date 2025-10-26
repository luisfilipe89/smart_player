import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/utils/profanity.dart';

void main() {
  group('Profanity Tests', () {
    test('should allow clean names', () {
      expect(Profanity.isNameAllowed('John'), true);
      expect(Profanity.isNameAllowed('Mary'), true);
      expect(Profanity.isNameAllowed('Alex123'), true);
      expect(Profanity.isNameAllowed('Test User'), true);
    });

    test('should block profane names', () {
      expect(Profanity.isNameAllowed('damn'), false);
      expect(Profanity.isNameAllowed('hell'), false);
      expect(Profanity.isNameAllowed('shit'), false);
    });

    test('should handle case insensitive', () {
      expect(Profanity.isNameAllowed('DAMN'), false);
      expect(Profanity.isNameAllowed('Hell'), false);
      expect(Profanity.isNameAllowed('SHIT'), false);
    });

    test('should handle names with profanity', () {
      expect(Profanity.isNameAllowed('damnuser'), false);
      expect(Profanity.isNameAllowed('userhell'), false);
      expect(Profanity.isNameAllowed('testshit'), false);
    });

    test('should allow names with profanity in different context', () {
      expect(Profanity.isNameAllowed('damnation'), true);
      expect(Profanity.isNameAllowed('shell'), true);
      expect(Profanity.isNameAllowed('shirt'), true);
    });

    test('should handle empty and null names', () {
      expect(Profanity.isNameAllowed(''), false);
      expect(Profanity.isNameAllowed('   '), false);
    });

    test('should handle special characters', () {
      expect(Profanity.isNameAllowed('user@123'), true);
      expect(Profanity.isNameAllowed('user-name'), true);
      expect(Profanity.isNameAllowed('user_name'), true);
    });
  });
}
