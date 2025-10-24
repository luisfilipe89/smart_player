// lib/screens/friends/qr_sharing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:move_young/services/qr_service.dart';
import 'package:move_young/providers/services/auth_provider.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/theme/app_back_button.dart';

class QRSharingScreen extends ConsumerWidget {
  const QRSharingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 48,
          leading: const AppBackButton(),
          title: Text('qr_share_title'.tr()),
        ),
        body: Center(
          child: Text('user_not_authenticated'.tr()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('qr_share_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareQRCode(context, currentUserId),
            tooltip: 'share_qr'.tr(),
          ),
        ],
      ),
      body: Padding(
        padding: AppPaddings.allMedium,
        child: Column(
          children: [
            // Header
            Text(
              'qr_share_description'.tr(),
              style: AppTextStyles.body.copyWith(
                color: AppColors.grey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppHeights.superHuge),

            // QR Code
            Container(
              padding: AppPaddings.allBig,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QRService.generateQRWidget(currentUserId, size: 250),
            ),

            const SizedBox(height: AppHeights.superHuge),

            // Share buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareQRCode(context, currentUserId),
                    icon: const Icon(Icons.share),
                    label: Text('share_qr'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: AppPaddings.allMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppWidths.big),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareQRCodeAsText(context, currentUserId),
                    icon: const Icon(Icons.text_fields),
                    label: Text('share_text'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: AppPaddings.allMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppHeights.superHuge),

            // Instructions
            Container(
              padding: AppPaddings.allMedium,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.blue,
                    size: 24,
                  ),
                  const SizedBox(height: AppHeights.small),
                  Text(
                    'qr_share_instructions'.tr(),
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareQRCode(BuildContext context, String userId) async {
    try {
      await QRService.shareQRCode(userId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('share_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareQRCodeAsText(BuildContext context, String userId) async {
    try {
      await QRService.shareQRCodeAsText(userId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('share_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }
}
