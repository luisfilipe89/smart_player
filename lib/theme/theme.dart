import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:move_young/theme/tokens.dart';

// where AppFonts lives

class AppTheme {
  static ThemeData minimal() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: AppColors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.blackIcon,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.title,
        iconTheme: IconThemeData(color: AppColors.blackIcon, size: 20),
        actionsIconTheme: IconThemeData(
          color: AppColors.blackIcon,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.white, // ← force white
          statusBarIconBrightness: Brightness.dark, // Android icons dark
          statusBarBrightness: Brightness.light, // iOS status bar
        ),
      ),
    );

    // A subtle, neutral chip background (same for selected & unselected)
    const chipBg =
        Color(0x0D000000); // ~5% black; tweak to your token if you want

    return base.copyWith(
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: chipBg,
        selectedColor: chipBg, // <- avoid Material default (pink)
        disabledColor: AppColors.lightgrey,
        labelStyle: AppTextStyles.small.copyWith(color: AppColors.blackText),
        secondaryLabelStyle:
            AppTextStyles.small.copyWith(color: AppColors.blackText),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(), // outline is set per-chip in your screen
      ),
    );
  }
}
