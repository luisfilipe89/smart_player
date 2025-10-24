// lib/screens/friends/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:move_young/services/qr_service.dart';
import 'package:move_young/providers/services/friends_provider.dart';
import 'package:move_young/providers/services/auth_provider.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/theme/app_back_button.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  MobileScannerController? _controller;
  bool _isScanning = true;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code != _lastScannedCode) {
        _lastScannedCode = code;
        _handleScannedCode(code);
      }
    }
  }

  void _handleScannedCode(String code) async {
    if (!mounted) return;

    setState(() {
      _isScanning = false;
    });

    // Parse the QR code
    final userId = QRService.parseUserQRData(code);
    if (userId == null) {
      _showErrorDialog('qr_invalid_code'.tr());
      return;
    }

    // Check if trying to add self
    final currentUserId = ref.read(currentUserIdProvider);
    if (userId == currentUserId) {
      _showErrorDialog('qr_cannot_add_self'.tr());
      return;
    }

    // Show confirmation dialog
    _showConfirmationDialog(userId);
  }

  void _showConfirmationDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('qr_add_friend_title'.tr()),
        content: Text('qr_add_friend_message'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isScanning = true;
                _lastScannedCode = null;
              });
            },
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendFriendRequest(userId);
            },
            child: Text('send_request'.tr()),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('error'.tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isScanning = true;
                _lastScannedCode = null;
              });
            },
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      final friendsActions = ref.read(friendsActionsProvider);
      final success = await friendsActions.sendFriendRequest(userId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('friend_request_sent'.tr()),
              backgroundColor: AppColors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('friend_request_failed'.tr()),
              backgroundColor: AppColors.red,
            ),
          );
          setState(() {
            _isScanning = true;
            _lastScannedCode = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('friend_request_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
        setState(() {
          _isScanning = true;
          _lastScannedCode = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('qr_scanner_title'.tr()),
        actions: [
          IconButton(
            icon: Icon(
              _isScanning ? Icons.flash_off : Icons.flash_on,
              color: Colors.white,
            ),
            onPressed: () {
              _controller?.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller!,
            onDetect: _onDetect,
          ),

          // Overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(),
                ),

                // Scanning area
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isScanning ? AppColors.primary : AppColors.grey,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isScanning
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: AppColors.green,
                            size: 48,
                          ),
                        ),
                ),

                Expanded(
                  child: Container(),
                ),

                // Instructions
                Container(
                  padding: AppPaddings.allMedium,
                  child: Text(
                    _isScanning
                        ? 'qr_scanner_instructions'.tr()
                        : 'qr_processing'.tr(),
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
