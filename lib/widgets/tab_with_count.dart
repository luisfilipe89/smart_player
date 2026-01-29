import 'package:flutter/material.dart';

/// Custom Tab widget that handles counter display with proper overflow handling
/// for all device sizes. Uses FittedBox to scale down content if needed,
/// ensuring the counter is always visible and not cut off.
class TabWithCount extends StatelessWidget {
  final String label;
  final int count;
  final bool showCount;

  const TabWithCount({
    super.key,
    required this.label,
    required this.count,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showCount || count == 0) {
      return Tab(text: label);
    }

    return Tab(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use FittedBox to scale down if content doesn't fit
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($count)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
