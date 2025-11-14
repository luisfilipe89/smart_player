import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/system/sync_service_instance.dart';
import '../../services/system/sync_provider.dart';
import '../../theme/tokens.dart';

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
    // Defer initialization until after the first frame to ensure platform channels are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeSyncListener();
      }
    });
  }

  void _initializeSyncListener() {
    try {
      final syncService = ref.read(syncServiceProvider);
      if (syncService == null) {
        debugPrint('Sync service not available yet');
        return;
      }

      _updateStatus();
      syncService.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            _currentStatus = status;
            _failedCount =
                ref.read(syncServiceProvider)?.failedOperationsCount ?? 0;
          });
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize sync listener: $e');
    }
  }

  void _updateStatus() {
    try {
      final syncService = ref.read(syncServiceProvider);
      if (syncService != null) {
        setState(() {
          _currentStatus = syncService.currentStatus;
          _failedCount = syncService.failedOperationsCount;
        });
      }
    } catch (e) {
      debugPrint('Failed to update sync status: $e');
    }
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
                        ref.read(syncServiceProvider)?.retryFailedOperations();
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
