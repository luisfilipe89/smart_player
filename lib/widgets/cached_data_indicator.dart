import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/connectivity/connectivity_provider.dart';
import 'package:move_young/theme/tokens.dart';

/// Widget that shows a banner when displaying cached/offline data
class CachedDataIndicator extends ConsumerWidget {
  final Widget child;
  final bool showWhenOffline;
  final String? customMessage;

  const CachedDataIndicator({
    super.key,
    required this.child,
    this.showWhenOffline = true,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityStatusProvider);

    return connectivityAsync.when(
      data: (isConnected) {
        if (isConnected || !showWhenOffline) {
          return child;
        }
        // Show cached data indicator when offline
        return Stack(
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  padding: AppPaddings.allSmall,
                  color: AppColors.amber.withValues(alpha: 0.9),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: AppWidths.small),
                      Expanded(
                        child: Text(
                          customMessage ?? 'showing_cached_data'.tr(),
                          style: AppTextStyles.small.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Trigger refresh if available
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('tap_to_refresh'.tr()),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          'tap_to_refresh'.tr(),
                          style: AppTextStyles.small.copyWith(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }
}

