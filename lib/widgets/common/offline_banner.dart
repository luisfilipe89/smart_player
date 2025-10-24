import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/connectivity/connectivity_provider.dart';
import '../../theme/tokens.dart';

/// Global offline/online status banner that appears at the top of the screen
class OfflineBanner extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  bool _isOffline = false;
  bool _isVisible = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _listenToConnectivity();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _listenToConnectivity() {
    ref.listen(connectivityStatusProvider, (previous, next) {
      next.whenData((isConnected) {
        if (mounted) {
          setState(() {
            final wasOffline = _isOffline;
            _isOffline = !isConnected;

            // Show banner when going offline or coming back online
            if (_isOffline != wasOffline) {
              _isVisible = true;
              if (_isOffline) {
                _animationController.forward();
              } else {
                // When coming back online, show green banner briefly then hide
                _animationController.reverse().then((_) {
                  if (mounted) {
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        setState(() {
                          _isVisible = false;
                        });
                      }
                    });
                  }
                });
              }
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value * 60),
                child: Container(
                  width: double.infinity,
                  height: 60,
                  color: _isOffline ? AppColors.red : AppColors.green,
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isOffline ? Icons.wifi_off : Icons.wifi,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOffline
                                ? 'offline_banner'.tr()
                                : 'online_banner'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
