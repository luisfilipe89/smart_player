import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/friends/friends_provider.dart';
import '../theme/tokens.dart';

/// Widget that shows rate limit feedback for friend requests
class RateLimitFeedback extends ConsumerStatefulWidget {
  final String uid;
  final Widget child;

  const RateLimitFeedback({
    super.key,
    required this.uid,
    required this.child,
  });

  @override
  ConsumerState<RateLimitFeedback> createState() => _RateLimitFeedbackState();
}

class _RateLimitFeedbackState extends ConsumerState<RateLimitFeedback> {
  Timer? _timer;
  int _remainingRequests = 10;
  Duration _remainingCooldown = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRateLimitInfo();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadRateLimitInfo() async {
    final friendsActions = ref.read(friendsActionsProvider);
    final remaining = await friendsActions.getRemainingRequests(widget.uid);
    final cooldown = await friendsActions.getRemainingCooldown(widget.uid);

    if (mounted) {
      setState(() {
        _remainingRequests = remaining;
        _remainingCooldown = cooldown;
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingCooldown.inSeconds > 0) {
        setState(() {
          _remainingCooldown =
              Duration(seconds: _remainingCooldown.inSeconds - 1);
        });
      } else {
        _loadRateLimitInfo();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.child;
    }

    return Column(
      children: [
        if (_remainingRequests <= 2 || _remainingCooldown.inSeconds > 0)
          Container(
            width: double.infinity,
            padding: AppPaddings.allSmall,
            margin: AppPaddings.bottomSmall,
            decoration: BoxDecoration(
              color: _remainingRequests <= 0
                  ? AppColors.red.withValues(alpha: 0.1)
                  : AppColors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color:
                    _remainingRequests <= 0 ? AppColors.red : AppColors.orange,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _remainingRequests <= 0 ? Icons.hourglass_empty : Icons.timer,
                  color: _remainingRequests <= 0
                      ? AppColors.red
                      : AppColors.orange,
                  size: 16,
                ),
                const SizedBox(width: AppWidths.small),
                Expanded(
                  child: Text(
                    _remainingRequests <= 0
                        ? 'rate_limit_exceeded'
                            .tr(args: [_formatDuration(_remainingCooldown)])
                        : 'rate_limit_remaining'
                            .tr(args: [_remainingRequests.toString()]),
                    style: AppTextStyles.small.copyWith(
                      color: _remainingRequests <= 0
                          ? AppColors.red
                          : AppColors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// Rate limit indicator for buttons
class RateLimitButton extends ConsumerWidget {
  final String uid;
  final VoidCallback? onPressed;
  final Widget child;
  final String? disabledMessage;

  const RateLimitButton({
    super.key,
    required this.uid,
    required this.onPressed,
    required this.child,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: ref.read(friendsActionsProvider).canSendFriendRequest(uid),
      builder: (context, snapshot) {
        final canSend = snapshot.data ?? true;

        return FutureBuilder<Duration>(
          future: ref.read(friendsActionsProvider).getRemainingCooldown(uid),
          builder: (context, cooldownSnapshot) {
            final cooldown = cooldownSnapshot.data ?? Duration.zero;

            return FutureBuilder<int>(
              future:
                  ref.read(friendsActionsProvider).getRemainingRequests(uid),
              builder: (context, remainingSnapshot) {
                final remaining = remainingSnapshot.data ?? 10;

                return Tooltip(
                  message: !canSend
                      ? 'rate_limit_exceeded'
                          .tr(args: [_formatDuration(cooldown)])
                      : remaining <= 2
                          ? 'rate_limit_remaining'
                              .tr(args: [remaining.toString()])
                          : null,
                  child: ElevatedButton(
                    onPressed: canSend ? onPressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canSend ? AppColors.primary : AppColors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: canSend
                        ? child
                        : Text(disabledMessage ?? 'Rate limited'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
