import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;
  final bool goHome;
  const AppBackButton(
      {super.key, this.onPressed, this.size = 20, this.goHome = false});

  void _switchToHomeTab(BuildContext context) {
    bool switched = false;

    // Walk up the ancestor tree and try to call `switchToTab(0, popToRoot: true)`
    context.visitAncestorElements((element) {
      final state = element is StatefulElement ? element.state : null;
      if (state != null) {
        try {
          // Dynamic call on any ancestor State that exposes switchToTab
          (state as dynamic).switchToTab(0, {'popToRoot': true});
          switched = true;
          return false; // stop visiting
        } catch (_) {
          try {
            // Some dynamic invocations require named args as normal named
            (state as dynamic).switchToTab(0, popToRoot: true);
            switched = true;
            return false;
          } catch (_) {}
        }
      }
      return true; // continue visiting
    });

    if (!switched) {
      // Fallback to a safe maybePop
      Navigator.maybePop(context);
    }
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
