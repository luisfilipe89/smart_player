import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/connectivity_service.dart';
import '../theme/tokens.dart';

/// Widget that shows when data is being displayed from cache
class CachedDataIndicator extends StatefulWidget {
  final Widget child;
  final bool isShowingCachedData;
  final VoidCallback? onRefresh;

  const CachedDataIndicator({
    super.key,
    required this.child,
    required this.isShowingCachedData,
    this.onRefresh,
  });

  @override
  State<CachedDataIndicator> createState() => _CachedDataIndicatorState();
}

class _CachedDataIndicatorState extends State<CachedDataIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.isShowingCachedData) {
      _showIndicator();
    }
  }

  @override
  void didUpdateWidget(CachedDataIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShowingCachedData != oldWidget.isShowingCachedData) {
      if (widget.isShowingCachedData) {
        _showIndicator();
      } else {
        _hideIndicator();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showIndicator() {
    if (!_isVisible) {
      setState(() => _isVisible = true);
      _animationController.forward();
    }
  }

  void _hideIndicator() {
    if (_isVisible) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isVisible)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: double.infinity,
              padding: AppPaddings.allSmall,
              margin: AppPaddings.bottomSmall,
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cached,
                    color: AppColors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: AppWidths.small),
                  Expanded(
                    child: Text(
                      'showing_cached_data'.tr(),
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.onRefresh != null)
                    TextButton(
                      onPressed: widget.onRefresh,
                      child: Text(
                        'tap_to_refresh'.tr(),
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// Hook widget that automatically shows cached data indicator based on connectivity
class ConnectivityAwareCachedIndicator extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const ConnectivityAwareCachedIndicator({
    super.key,
    required this.child,
    this.onRefresh,
  });

  @override
  State<ConnectivityAwareCachedIndicator> createState() =>
      _ConnectivityAwareCachedIndicatorState();
}

class _ConnectivityAwareCachedIndicatorState
    extends State<ConnectivityAwareCachedIndicator> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService.hasConnection;
    ConnectivityService.isConnected.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOffline = !isConnected;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CachedDataIndicator(
      isShowingCachedData: _isOffline,
      onRefresh: widget.onRefresh,
      child: widget.child,
    );
  }
}
