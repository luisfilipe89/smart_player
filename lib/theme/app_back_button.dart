import 'package:flutter/material.dart';
import 'package:move_young/screens/main_scaffold.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;
  final bool goHome;
  const AppBackButton(
      {super.key, this.onPressed, this.size = 20, this.goHome = false});

  void _switchToHomeTab(BuildContext context) {
    final controller = MainScaffoldScope.maybeOf(context);
    if (controller != null) {
      controller.switchToTab(0, popToRoot: true);
      return;
    }
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back_ios_new, size: size),
      color: Theme.of(context).appBarTheme.iconTheme?.color,
      onPressed: onPressed ??
          () {
            if (goHome) {
              _switchToHomeTab(context);
            } else {
              Navigator.maybePop(context);
            }
          },
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}
