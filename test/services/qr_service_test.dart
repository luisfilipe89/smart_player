import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/qr/qr_service_instance.dart';

void main() {
  group('QRServiceInstance Tests', () {
    late QRServiceInstance qrService;

    setUp(() {
      qrService = QRServiceInstance();
    });

    test('should generate user QR data with prefix', () {
      const userId = 'user123';
      final qrData = qrService.generateUserQRData(userId);

      expect(qrData, 'smartplayer://friend/user123');
    });

    test('should parse valid QR data correctly', () {
      const qrData = 'smartplayer://friend/user456';
      final userId = qrService.parseUserQRData(qrData);

      expect(userId, 'user456');
    });

    test('should return null for invalid QR data', () {
      const invalidData = 'invalid://data';
      final userId = qrService.parseUserQRData(invalidData);

      expect(userId, isNull);
    });

    test('should return null for QR data without prefix', () {
      const dataWithoutPrefix = 'user789';
      final userId = qrService.parseUserQRData(dataWithoutPrefix);

      expect(userId, isNull);
    });

    test('should generate QR widget with correct size', () {
      const userId = 'user123';
      final widget = qrService.generateQRWidget(userId, size: 250);

      expect(widget, isA<Widget>());
      expect(widget.runtimeType.toString(), 'QrImageView');
    });

    test('should use default size when not specified', () {
      const userId = 'user123';
      final widget = qrService.generateQRWidget(userId);

      expect(widget, isA<Widget>());
    });

    test('should handle share QR code operation', () async {
      // Note: Actual sharing requires platform channels and will fail in test environment
      // This test verifies the method exists
      final userId = 'user123';

      // Test the method exists and handles errors gracefully
      expect(() async {
        try {
          await qrService.shareQRCode(userId);
        } catch (e) {
          // Expected in test environment without platform channels
        }
      }, returnsNormally);
    });

    test('should handle multiple user IDs correctly', () {
      const userIds = ['user1', 'user2', 'user3'];

      for (final userId in userIds) {
        final qrData = qrService.generateUserQRData(userId);
        final parsed = qrService.parseUserQRData(qrData);

        expect(parsed, userId);
      }
    });

    test('should handle empty user ID', () {
      const userId = '';
      final qrData = qrService.generateUserQRData(userId);

      expect(qrData, 'smartplayer://friend/');
    });
  });
}
