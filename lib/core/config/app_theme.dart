// lib/core/config/app_theme.dart
//
// Centralized theme file for the entire staff app.
// Based on the "Heritage Digital" color palette — matches the parent app.
//
// To change the entire app's look-and-feel, edit ONLY the [AppColors]
// constants and the [AppTheme.lightTheme] builder below. Every screen
// that uses Theme.of(context) will automatically pick up the changes.

import 'package:flutter/material.dart';
import '../branding/branding.dart';
import 'app_colors.dart';
import 'app_text_theme.dart';

// =============================================================================
// App Theme Builder
// =============================================================================

abstract final class AppTheme {
  AppTheme._();

  /// Build the app theme from a resolved [Branding]. Applies the brand to
  /// [AppColors] first so direct `AppColors.x` reads across the app stay in sync.
  static ThemeData build(Branding branding) {
    AppColors.applyBranding(branding);
    return _theme();
  }

  /// Convenience: the theme for the compile-time fallback brand.
  static ThemeData get lightTheme => build(const Branding.fallback());

  static ThemeData _theme() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.textOnPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textOnSecondary,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: AppColors.textOnSecondary,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.textPrimary,
      tertiaryContainer: AppColors.tertiaryLight,
      onTertiaryContainer: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.textOnPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTextTheme.lightTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textOnPrimary),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Decoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),

      // ── Bottom Navigation ─────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),

      // ── Drawer ────────────────────────────────────────────────────────────
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary,
        // The label colour MUST follow the selected state, because the two
        // backgrounds above are at opposite ends of the scale: unselected is
        // near-white and selected is the dark brand colour. Leaving the colour
        // null let the default resolve to one tone for both, so a filter chip
        // was light-on-light when off and dark-on-dark when on — legible in
        // neither state. A WidgetStateColor is a Color, so it drops straight
        // into TextStyle.
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.textOnPrimary
                : AppColors.textPrimary,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),

      // ── Floating Action Button ────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 4,
        // StadiumBorder, NOT CircleBorder. The theme's shape applies to EVERY
        // FAB, and `FloatingActionButton.extended` is a pill — a CircleBorder
        // clipped it to a circle and cut its label off mid-word ("New pap…").
        //
        // A stadium on the square 56×56 plain FAB renders as the same circle it
        // did before, so this changes nothing for the plain ones and fixes the
        // extended ones. Do not "restore" CircleBorder.
        shape: const StadiumBorder(),
      ),

      // ── Snackbar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: TextStyle(color: AppColors.textOnPrimary, fontSize: 14),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // ── Tab Bar ───────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textOnPrimary,
        unselectedLabelColor: const Color(0xAAFFFFFF),
        indicatorColor: AppColors.tertiary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.textHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryLight.withAlpha(100);
          return AppColors.border;
        }),
      ),

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.border,
      ),
    );
  }
}
