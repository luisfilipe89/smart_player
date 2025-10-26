import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validation Tests', () {
    test('should validate email addresses', () {
      expect(_isValidEmail('test@example.com'), true);
      expect(_isValidEmail('user@domain.co.uk'), true);
      expect(_isValidEmail('invalid-email'), false);
      expect(_isValidEmail('@domain.com'), false);
      expect(_isValidEmail('user@'), false);
    });

    test('should validate phone numbers', () {
      expect(_isValidPhone('+1234567890'), true);
      expect(_isValidPhone('123-456-7890'), true);
      expect(_isValidPhone('(123) 456-7890'), true);
      expect(_isValidPhone('invalid'), false);
      expect(_isValidPhone('123'), false);
    });

    test('should validate names', () {
      expect(_isValidName('John Doe'), true);
      expect(_isValidName('Mary Jane'), true);
      expect(_isValidName(''), false);
      expect(_isValidName('   '), false);
      expect(_isValidName('A'), false); // Too short
    });
  });
}

// Helper validation functions for testing
bool _isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

bool _isValidPhone(String phone) {
  return RegExp(r'^[\+]?[1-9][\d]{0,15}$')
      .hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
}

bool _isValidName(String name) {
  return name.trim().length >= 2;
}
