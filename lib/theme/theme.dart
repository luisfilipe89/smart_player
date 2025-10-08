import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:move_young/theme/tokens.dart';

// where AppFonts lives

class AppTheme {
  static ThemeData minimal() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: AppColors.primary,
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
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

  static ThemeData highContrast() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.highContrastPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      background: AppColors.highContrastBackground,
      surface: AppColors.highContrastSurface,
      onBackground: AppColors.highContrastText,
      onSurface: AppColors.highContrastText,
      primary: AppColors.highContrastPrimary,
      onPrimary: AppColors.highContrastBackground,
      secondary: AppColors.highContrastSecondary,
      onSecondary: AppColors.highContrastBackground,
      error: AppColors.highContrastError,
      onError: AppColors.highContrastText,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: AppColors.highContrastPrimary,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: AppColors.highContrastBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.highContrastBackground,
        foregroundColor: AppColors.highContrastText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle:
            AppTextStyles.title.copyWith(color: AppColors.highContrastText),
        iconTheme: IconThemeData(color: AppColors.highContrastText, size: 20),
        actionsIconTheme: IconThemeData(
          color: AppColors.highContrastText,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.highContrastBackground,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.highContrastPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.highContrastPrimary,
        contentTextStyle: TextStyle(color: AppColors.highContrastBackground),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide:
              BorderSide(color: AppColors.highContrastPrimary, width: 3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: AppColors.highContrastBorder, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.highContrastText),
        hintStyle:
            TextStyle(color: AppColors.highContrastText.withOpacity(0.7)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.highContrastPrimary,
          foregroundColor: AppColors.highContrastBackground,
          side: BorderSide(color: AppColors.highContrastBorder, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.highContrastPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.highContrastText,
          side: BorderSide(color: AppColors.highContrastBorder, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.highContrastPrimary;
          }
          return AppColors.highContrastText;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.highContrastPrimary.withOpacity(0.5);
          }
          return AppColors.highContrastSurface;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.highContrastPrimary;
          }
          return AppColors.highContrastText;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.highContrastBorder,
        thickness: 2,
      ),
    );

    return base.copyWith(
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.highContrastSurface,
        selectedColor: AppColors.highContrastPrimary.withOpacity(0.3),
        disabledColor: AppColors.highContrastSurface,
        labelStyle:
            AppTextStyles.small.copyWith(color: AppColors.highContrastText),
        secondaryLabelStyle:
            AppTextStyles.small.copyWith(color: AppColors.highContrastText),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(),
        side: BorderSide(color: AppColors.highContrastBorder, width: 1),
      ),
    );
  }
}
