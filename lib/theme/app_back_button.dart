import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;
  final bool goHome;
  const AppBackButton(
      {super.key, this.onPressed, this.size = 20, this.goHome = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back_ios_new, size: size),
      color: Theme.of(context).appBarTheme.iconTheme?.color,
      onPressed: onPressed ??
          () {
            if (goHome) {
              // Switch to Home tab if available
              // Import kept local to avoid circular deps; using dynamic lookup
              // Weakly-typed lookup to avoid direct dependency on MainScaffold
              final state =
                  context.findAncestorStateOfType<State<StatefulWidget>>();
              bool switched = false;
              if (state != null) {
                final dynamic dyn = state;
                try {
                  dyn.switchToTab(0, popToRoot: true);
                  switched = true;
                } catch (_) {}
              }
              if (!switched) {
                Navigator.maybePop(context);
              }
            } else {
              Navigator.maybePop(context);
            }
          },
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}
