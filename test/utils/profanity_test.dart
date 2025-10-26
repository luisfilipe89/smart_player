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
      expect(Profanity.isNameAllowed('fuck'), false);
      expect(Profanity.isNameAllowed('shit'), false);
      expect(Profanity.isNameAllowed('bitch'), false);
    });

    test('should handle case insensitive', () {
      expect(Profanity.isNameAllowed('FUCK'), false);
      expect(Profanity.isNameAllowed('Shit'), false);
      expect(Profanity.isNameAllowed('BItCh'), false);
    });

    test('should handle names with profanity', () {
      expect(Profanity.isNameAllowed('fuckuser'), false);
      expect(Profanity.isNameAllowed('usershit'), false);
      expect(Profanity.isNameAllowed('testbitch'), false);
    });

    test('should allow names with profanity in different context', () {
      // These words contain profanity but in a different context
      // The actual implementation checks for word boundaries
      expect(Profanity.isNameAllowed('damnation'), true);
      expect(Profanity.isNameAllowed('shell'), true);
      expect(Profanity.isNameAllowed('shirt'), true);
    });

    test('should handle empty and null names', () {
      expect(Profanity.isNameAllowed(''), true); // Empty string is allowed
      expect(Profanity.isNameAllowed('   '), true); // Spaces only is allowed
    });

    test('should handle special characters', () {
      expect(Profanity.isNameAllowed('user@123'), true);
      expect(Profanity.isNameAllowed('user-name'), true);
      expect(Profanity.isNameAllowed('user_name'), true);
    });

    test('should handle Dutch profanity', () {
      expect(Profanity.isNameAllowed('kanker'), false);
      expect(Profanity.isNameAllowed('tyfus'), false);
      expect(Profanity.isNameAllowed('tering'), false);
    });

    test('should normalize characters', () {
      // Test that normalization works correctly
      // 'h4ck' becomes 'hck' after removing numbers
      expect(Profanity.isNameAllowed('h4ck'), true); // Numbers removed

      // Test actual profanity that would be blocked
      expect(Profanity.isNameAllowed('fuck'), false);
      expect(Profanity.isNameAllowed('shit'), false);
    });
  });
}
