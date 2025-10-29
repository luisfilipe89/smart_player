import 'package:flutter/material.dart';
import 'package:move_young/theme/tokens.dart';

class SuccessCheckmarkOverlay extends StatefulWidget {
  final Duration duration;
  final Widget child;
  final bool show;

  const SuccessCheckmarkOverlay({
    super.key,
    required this.child,
    required this.show,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<SuccessCheckmarkOverlay> createState() =>
      _SuccessCheckmarkOverlayState();
}

class _SuccessCheckmarkOverlayState extends State<SuccessCheckmarkOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.show) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant SuccessCheckmarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: true,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                if (_controller.value == 0 && !widget.show)
                  return const SizedBox.shrink();
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 36),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
