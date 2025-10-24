import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/system/sync_service_instance.dart';
import '../../services/system/sync_provider.dart';
import '../../theme/tokens.dart';

/// Widget that shows sync status indicator
class SyncStatusIndicator extends ConsumerStatefulWidget {
  final String? itemId;
  final Widget child;

  const SyncStatusIndicator({
    super.key,
    this.itemId,
    required this.child,
  });

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator> {
  SyncStatus _currentStatus = SyncStatus.synced;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    ref.read(syncServiceProvider).statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _failedCount = ref.read(syncServiceProvider).failedOperationsCount;
        });
      }
    });
  }

  void _updateStatus() {
    setState(() {
      _currentStatus = ref.read(syncServiceProvider).currentStatus;
      _failedCount = ref.read(syncServiceProvider).failedOperationsCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentStatus != SyncStatus.synced)
          Positioned(
            top: 4,
            right: 4,
            child: _buildStatusIcon(),
          ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    switch (_currentStatus) {
      case SyncStatus.pending:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.orange,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.sync,
            color: Colors.white,
            size: 12,
          ),
        );
      case SyncStatus.failed:
        return GestureDetector(
          onTap: () => _showRetryDialog(context, ref.read(syncServiceProvider)),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sync_problem,
              color: Colors.white,
              size: 12,
            ),
          ),
        );
      case SyncStatus.synced:
        return const SizedBox.shrink();
    }
  }

  void _showRetryDialog(BuildContext context, SyncServiceInstance syncService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('sync_failed'.tr()),
        content: Text('items_failed_sync'.tr(args: [_failedCount.toString()])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              syncService.retryFailedOperations();
              Navigator.of(context).pop();
            },
            child: Text('sync_retry'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Global sync status banner
class GlobalSyncStatusBanner extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalSyncStatusBanner({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalSyncStatusBanner> createState() =>
      _GlobalSyncStatusBannerState();
}

class _GlobalSyncStatusBannerState
    extends ConsumerState<GlobalSyncStatusBanner> {
  SyncStatus _currentStatus = SyncStatus.synced;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    ref.read(syncServiceProvider).statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _failedCount = ref.read(syncServiceProvider).failedOperationsCount;
        });
      }
    });
  }

  void _updateStatus() {
    setState(() {
      _currentStatus = ref.read(syncServiceProvider).currentStatus;
      _failedCount = ref.read(syncServiceProvider).failedOperationsCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentStatus == SyncStatus.failed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: AppPaddings.allSmall,
                color: AppColors.red,
                child: Row(
                  children: [
                    const Icon(
                      Icons.sync_problem,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: AppWidths.small),
                    Expanded(
                      child: Text(
                        'items_failed_sync'.tr(args: [_failedCount.toString()]),
                        style: AppTextStyles.small.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(syncServiceProvider).retryFailedOperations();
                      },
                      child: Text(
                        'sync_retry'.tr(),
                        style: AppTextStyles.small.copyWith(
                          color: Colors.white,
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
  }
}

/// Sync status chip for lists
class SyncStatusChip extends ConsumerWidget {
  final String? itemId;
  final SyncStatus status;

  const SyncStatusChip({
    super.key,
    this.itemId,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (status) {
      case SyncStatus.synced:
        return const SizedBox.shrink();
      case SyncStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.orange, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sync,
                color: AppColors.orange,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                'sync_pending'.tr(),
                style: AppTextStyles.small.copyWith(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case SyncStatus.failed:
        return GestureDetector(
          onTap: () => _showRetryDialog(context, ref.read(syncServiceProvider)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.red, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sync_problem,
                  color: AppColors.red,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'sync_failed'.tr(),
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  void _showRetryDialog(BuildContext context, SyncServiceInstance syncService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('sync_failed'.tr()),
        content: Text('Tap to retry sync'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              syncService.retryFailedOperations();
              Navigator.of(context).pop();
            },
            child: Text('sync_retry'.tr()),
          ),
        ],
      ),
    );
  }
}
