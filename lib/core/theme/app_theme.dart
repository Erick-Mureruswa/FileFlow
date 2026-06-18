import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const background = Color(0xFF070A12);
  static const surface = Color(0xFF0F1623);
  static const card = Color(0xFF161E2E);
  static const cardBorder = Color(0xFF1E2A3F);
  static const accent = Color(0xFF7C6FFF);
  static const accentDim = Color(0xFF5248CC);
  static const accentGlow = Color(0x267C6FFF);
  static const star = Color(0xFFF59E0B);
  static const danger = Color(0xFFFF5252);
  static const dangerGlow = Color(0x26FF5252);
  static const safe = Color(0xFF00D68F);
  static const safeGlow = Color(0x2600D68F);
  static const warning = Color(0xFFFF8C42);
  static const textPrimary = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF8B9DBE);
  static const textMuted = Color(0xFF3D4F6E);
  static const divider = Color(0xFF151F30);
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.star,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: AppColors.textPrimary,
      onSecondary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
      onError: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: AppColors.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          );
        }
        return const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.accent, size: 22);
        }
        return const IconThemeData(color: AppColors.textMuted, size: 22);
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      side: const BorderSide(color: AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: 0.1,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.accent.withValues(alpha: 0.3)
            : AppColors.card;
      }),
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: AppColors.textPrimary,
      iconColor: AppColors.textSecondary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.card,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
