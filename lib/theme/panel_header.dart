// widgets/panel_header.dart
import 'package:flutter/material.dart';
import 'package:move_young/theme/tokens.dart';

class PanelHeader extends StatelessWidget {
  final String text;
  const PanelHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPaddings.allReg, // <- unify this
      child: SizedBox(
        width: double.infinity, // <- and this
        child: Text(text,
            style: AppTextStyles.headline, textAlign: TextAlign.start),
      ),
    );
  }
}
