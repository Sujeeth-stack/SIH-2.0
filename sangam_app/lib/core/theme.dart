import 'package:flutter/material.dart';

/// "Clean civic white" — the only colours the app is allowed to use.
/// One calm accent, soft status tints, no gradients and no dark mode in Phase 1.
class AppColors {
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF6F7F9);
  static const border = Color(0xFFE3E6EA);
  static const textPrimary = Color(0xFF1B1F24);
  static const textSecondary = Color(0xFF5B6470);
  static const primary = Color(0xFF1F5FBF);
  static const primarySoft = Color(0xFFE8F0FC);
  static const success = Color(0xFF1E8E5A);
  static const successSoft = Color(0xFFE6F4EC);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFBF3E4);
  static const danger = Color(0xFFC0392B);
  static const dangerSoft = Color(0xFFFBEAE8);
}

/// The bundled type stack. Any explicit TextStyle in a component theme must
/// carry these, otherwise it silently falls back to the platform font.
const kFontFamily = 'Inter';
const kFontFallback = <String>['NotoSansDevanagari'];

/// 8-pt spacing grid.
class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

  // Inter for Latin; Noto Sans Devanagari carries Hindi so it never falls back
  // to whatever the device happens to ship. Both are bundled assets, so type
  // renders identically offline and on first launch.
  final text = base.textTheme.apply(
    fontFamily: 'Inter',
    fontFamilyFallback: const ['NotoSansDevanagari'],
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  const inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: AppColors.border),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      outline: AppColors.border,
    ),
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium
          ?.copyWith(fontSize: 28, fontWeight: FontWeight.w600, height: 1.25),
      titleLarge: text.titleLarge
          ?.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25),
      titleMedium: text.titleMedium
          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
      bodySmall: text.bodySmall
          ?.copyWith(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
      labelLarge: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontFamilyFallback: kFontFallback,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      hintStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontFamilyFallback: kFontFallback,
        color: AppColors.textSecondary,
      ),
      labelStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontFamilyFallback: kFontFallback,
        color: AppColors.textSecondary,
      ),
      helperStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontFamilyFallback: kFontFallback,
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.primarySoft,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontFamilyFallback: kFontFallback,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      elevation: 0,
      height: 68,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceAlt,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
