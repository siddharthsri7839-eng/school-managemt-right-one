// lib/core/config/app_colors.dart
//
// Centralized color tokens for the entire staff app.
// Mirrors the parent app's "Heritage Digital" palette for brand consistency.
//
// To change the entire app's color scheme, edit ONLY this file.
// Every screen that uses Theme.of(context) or AppColors.xxx will
// automatically pick up the changes.

import 'package:flutter/material.dart';
import '../branding/branding.dart';

/// All brand & semantic colors live here. Import this class anywhere you need
/// a raw color that isn't covered by [Theme.of(context).colorScheme].
///
/// NOTE: the brand tokens below are intentionally NOT `const` — they are set by
/// [applyBranding] at bootstrap and on any branding change. Do not use them in
/// `const` expressions. See backend docs/dynamic-branding-plan.md §5.3.
abstract final class AppColors {
  AppColors._();

  // ── Brand Palette (RUNTIME-mutable — set by applyBranding) ──────────────────
  /// Dark navy — primary brand color for headers, AppBar, hero sections
  static Color primary = const Color(0xFF1A365D);

  /// Slightly lighter navy for gradients and hover states
  static Color primaryLight = const Color(0xFF2A4A7F);

  /// Even darker navy for pressed states
  static Color primaryDark = const Color(0xFF0F2341);

  /// Staff-specific accent — the original orange brand color
  static Color accent = const Color(0xFFF37021);

  /// Lighter accent variant for backgrounds (derived from accent)
  static Color accentLight = const Color(0xFFFF8F4C);

  /// Deep crimson — secondary accent for badges, alerts, important CTAs
  static Color secondary = const Color(0xFF9B2C2C);

  /// Lighter crimson variant (not brand-configurable)
  static const Color secondaryLight = Color(0xFFBC4444);

  /// Heritage gold — highlights, premium accents, star ratings
  static Color tertiary = const Color(0xFFD4AF37);

  /// Muted gold for backgrounds and light accents
  static const Color tertiaryLight = Color(0xFFF5ECD0);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  /// Warm off-white background for the entire app (softer than pure white)
  static const Color background = Color(0xFFF5F6FA);

  /// Soft off-white for cards and elevated surfaces (avoids harsh pure white)
  static const Color surface = Color(0xFFFAFBFD);

  /// Slightly deeper tinted surface for secondary cards / alternate rows
  static const Color surfaceVariant = Color(0xFFEEF0F4);

  /// Card border / divider color
  static const Color border = Color(0xFFDFE3EB);

  // ── Text ───────────────────────────────────────────────────────────────────
  /// Primary text on light backgrounds
  static const Color textPrimary = Color(0xFF1E293B);

  /// Secondary / muted text
  static const Color textSecondary = Color(0xFF64748B);

  /// Hint / placeholder text
  static const Color textHint = Color(0xFF94A3B8);

  /// Text on dark / primary backgrounds (RUNTIME-mutable — luminance-safe via brand)
  static Color textOnPrimary = const Color(0xFFFFFFFF);

  /// Text on secondary backgrounds
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // ── Status ─────────────────────────────────────────────────────────────────
  /// Success states — attendance present, approved
  static const Color success = Color(0xFF16A34A);

  /// Light success background
  static const Color successBg = Color(0xFFDCFCE7);

  /// Warning states — pending, upcoming deadlines
  static const Color warning = Color(0xFFF59E0B);

  /// Light warning background
  static const Color warningBg = Color(0xFFFEF3C7);

  /// Error / danger — absent, rejected, failed
  static const Color error = Color(0xFFDC2626);

  /// Light error background
  static const Color errorBg = Color(0xFFFEE2E2);

  /// Informational — neutral alerts, tips
  static const Color info = Color(0xFF3B82F6);

  /// Light info background
  static const Color infoBg = Color(0xFFDBEAFE);

  // ── Dashboard Quick Action Icon Backgrounds ────────────────────────────────
  static const Color iconBgAttendance = Color(0xFFDCFCE7);
  static const Color iconBgHomework = Color(0xFFF3E8FF);
  static const Color iconBgExams = Color(0xFFDBEAFE);
  static const Color iconBgTimetable = Color(0xFFFEF3C7);
  static const Color iconBgFees = Color(0xFFFEE2E2);
  static const Color iconBgNotices = Color(0xFFFCE7F3);
  static const Color iconBgStudents = Color(0xFFE0F2FE);
  static const Color iconBgLeave = Color(0xFFF5F3FF);
  static const Color iconBgStaff = Color(0xFFE0E7FF);
  static const Color iconBgProfile = Color(0xFFF0F9FF);
  static const Color iconBgChatbot = Color(0xFFCCFBF1);
  static const Color iconBgComms = Color(0xFFFFF7ED);
  static const Color iconBgSurvey = Color(0xFFEEF2FF);

  // ── Icon Foreground Colors (matching tints) ────────────────────────────────
  static const Color iconFgAttendance = Color(0xFF16A34A);
  static const Color iconFgHomework = Color(0xFF9333EA);
  static const Color iconFgExams = Color(0xFF2563EB);
  static const Color iconFgTimetable = Color(0xFFD97706);
  static const Color iconFgFees = Color(0xFFDC2626);
  static const Color iconFgNotices = Color(0xFFEC4899);
  static const Color iconFgStudents = Color(0xFF0284C7);
  static const Color iconFgLeave = Color(0xFF7C3AED);
  static const Color iconFgStaff = Color(0xFF4F46E5);
  static const Color iconFgProfile = Color(0xFF0369A1);
  static const Color iconFgChatbot = Color(0xFF0D9488);
  static const Color iconFgComms = Color(0xFFEA580C);
  static const Color iconFgSurvey = Color(0xFF4F46E5);

  // ── Carousel / Banner (RUNTIME-mutable — follow the primary brand) ──────────
  /// Gradient start for hero banner sections
  static Color bannerGradientStart = const Color(0xFF1A365D);

  /// Gradient end for hero banner sections
  static Color bannerGradientEnd = const Color(0xFF2A4A7F);

  /// Apply a resolved [Branding] to the runtime-mutable brand tokens. Called at
  /// bootstrap and on every branding change (via [AppTheme.build]).
  static void applyBranding(Branding b) {
    primary = b.primary;
    primaryLight = b.primaryLight;
    primaryDark = b.primaryDark;
    accent = b.accent;
    accentLight = Color.lerp(b.accent, Colors.white, 0.28) ?? b.accent;
    secondary = b.secondary;
    tertiary = b.tertiary;
    textOnPrimary = b.onPrimary;
    bannerGradientStart = b.primary;
    bannerGradientEnd = b.primaryLight;
  }
}
