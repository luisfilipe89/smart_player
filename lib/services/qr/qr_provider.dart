import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'qr_service_instance.dart';

/// QRService provider with dependency injection
final qrServiceProvider = Provider<QRServiceInstance>((ref) {
  return QRServiceInstance();
});

/// QR actions provider (for QR operations)
final qrActionsProvider = Provider<QRActions>((ref) {
  final qrService = ref.watch(qrServiceProvider);
  return QRActions(qrService);
});

/// Helper class for QR actions
class QRActions {
  final QRServiceInstance _qrService;

  QRActions(this._qrService);

  String generateUserQRData(String userId) =>
      _qrService.generateUserQRData(userId);
  String? parseUserQRData(String qrData) => _qrService.parseUserQRData(qrData);
  Widget generateQRWidget(String userId, {double size = 200}) =>
      _qrService.generateQRWidget(userId, size: size);
  Future<void> shareQRCode(String userId) => _qrService.shareQRCode(userId);
}
