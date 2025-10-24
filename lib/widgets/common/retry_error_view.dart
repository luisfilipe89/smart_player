import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/tokens.dart';

/// Reusable error state widget with retry functionality
class RetryErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final String? retryText;

  const RetryErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.icon,
    this.retryText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPaddings.allMedium,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.error_outline,
            color: AppColors.grey,
            size: 48,
          ),
          const SizedBox(height: AppHeights.reg),
          Text(
            message ?? 'operation_failed'.tr(),
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppHeights.big),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(retryText ?? 'retry'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
