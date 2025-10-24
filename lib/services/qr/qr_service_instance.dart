import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Instance-based QRService for use with Riverpod dependency injection
class QRServiceInstance {
  static const String _qrPrefix = 'smartplayer://friend/';

  /// Generate QR code data for a user
  String generateUserQRData(String userId) {
    return '$_qrPrefix$userId';
  }

  /// Parse QR code data to extract user ID
  String? parseUserQRData(String qrData) {
    if (qrData.startsWith(_qrPrefix)) {
      return qrData.substring(_qrPrefix.length);
    }
    return null;
  }

  /// Generate QR code widget for a user
  Widget generateQRWidget(String userId, {double size = 200}) {
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
  Future<void> shareQRCode(String userId) async {
    final qrData = generateUserQRData(userId);
    await Share.share(
      'Add me as a friend on SmartPlayer!\n$qrData',
      subject: 'SmartPlayer Friend Invite',
    );
  }
}
