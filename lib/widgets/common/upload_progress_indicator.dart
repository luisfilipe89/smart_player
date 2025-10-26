import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/tokens.dart';

/// Upload progress indicator with retry functionality
class UploadProgressIndicator extends StatefulWidget {
  final double progress;
  final String? message;
  final bool isError;
  final bool isSuccess;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const UploadProgressIndicator({
    super.key,
    required this.progress,
    this.message,
    this.isError = false,
    this.isSuccess = false,
    this.onRetry,
    this.onDismiss,
  });

  @override
  State<UploadProgressIndicator> createState() =>
      _UploadProgressIndicatorState();
}

class _UploadProgressIndicatorState extends State<UploadProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();

    // Auto-dismiss on success after 2 seconds
    if (widget.isSuccess && widget.onDismiss != null) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          widget.onDismiss?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: AppPaddings.allMedium,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.container),
              boxShadow: AppShadows.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(),
                const SizedBox(height: AppHeights.reg),
                _buildMessage(),
                if (widget.isError && widget.onRetry != null) ...[
                  const SizedBox(height: AppHeights.reg),
                  _buildRetryButton(),
                ],
                if (widget.onDismiss != null && !widget.isSuccess) ...[
                  const SizedBox(height: AppHeights.small),
                  _buildDismissButton(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    if (widget.isError) {
      return const Icon(
        Icons.error_outline,
        color: AppColors.red,
        size: 48,
      );
    }

    if (widget.isSuccess) {
      return const Icon(
        Icons.check_circle,
        color: AppColors.green,
        size: 48,
      );
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: widget.progress,
            strokeWidth: 4,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          Center(
            child: Text(
              '${(widget.progress * 100).toInt()}%',
              style: AppTextStyles.small.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage() {
    String message;
    if (widget.isError) {
      message = widget.message ?? 'upload_failed'.tr();
    } else if (widget.isSuccess) {
      message = 'Upload completed successfully';
    } else {
      message = widget.message ??
          'uploading'.tr(args: ['${(widget.progress * 100).toInt()}']);
    }

    return Text(
      message,
      style: AppTextStyles.body,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRetryButton() {
    return ElevatedButton.icon(
      onPressed: widget.onRetry,
      icon: const Icon(Icons.refresh, size: 18),
      label: Text('upload_retry'.tr()),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
  }

  Widget _buildDismissButton() {
    return TextButton(
      onPressed: widget.onDismiss,
      child: Text(
        'Dismiss',
        style: AppTextStyles.small.copyWith(
          color: AppColors.grey,
        ),
      ),
    );
  }
}

/// Overlay widget for showing upload progress
class UploadProgressOverlay extends StatelessWidget {
  final double progress;
  final String? message;
  final bool isError;
  final bool isSuccess;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const UploadProgressOverlay({
    super.key,
    required this.progress,
    this.message,
    this.isError = false,
    this.isSuccess = false,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blackTransparent,
      child: Center(
        child: UploadProgressIndicator(
          progress: progress,
          message: message,
          isError: isError,
          isSuccess: isSuccess,
          onRetry: onRetry,
          onDismiss: onDismiss,
        ),
      ),
    );
  }
}
