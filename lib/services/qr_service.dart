// lib/services/qr_service.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Service for QR code generation, scanning, and sharing
class QRService {
  static const String _qrPrefix = 'smartplayer://friend/';

  /// Generate QR code data for a user
  static String generateUserQRData(String userId) {
    return '$_qrPrefix$userId';
  }

  /// Parse QR code data to extract user ID
  static String? parseUserQRData(String qrData) {
    if (qrData.startsWith(_qrPrefix)) {
      return qrData.substring(_qrPrefix.length);
    }
    return null;
  }

  /// Generate QR code widget for a user
  static Widget generateQRWidget(String userId, {double size = 200}) {
    final qrData = generateUserQRData(userId);
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
  }

  /// Share QR code as image
  static Future<void> shareQRCode(String userId) async {
    try {
      final qrData = generateUserQRData(userId);

      // Generate QR code as image
      final qrImage = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ).toImageData(200);

      if (qrImage != null) {
        // Convert to bytes
        final bytes = qrImage.buffer.asUint8List();

        // Share the QR code
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: 'friend_qr.png', mimeType: 'image/png')],
          text: 'Add me as a friend on Smart Player!',
        );
      }
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
    }
  }

  /// Share QR code as text (fallback)
  static Future<void> shareQRCodeAsText(String userId) async {
    try {
      final qrData = generateUserQRData(userId);
      await Share.share(
        'Add me as a friend on Smart Player!\n\nScan this QR code or use this link: $qrData',
        subject: 'Smart Player Friend Invite',
      );
    } catch (e) {
      debugPrint('Error sharing QR code as text: $e');
    }
  }

  /// Validate if QR code data is valid for friend requests
  static bool isValidFriendQRData(String qrData) {
    return qrData.startsWith(_qrPrefix) &&
        qrData.length > _qrPrefix.length &&
        qrData.substring(_qrPrefix.length).isNotEmpty;
  }
}
