// lib/core/config/app_text_theme.dart
//
// Centralized typography scale for the staff app.
// Matches the parent app's type system for consistency.

import 'package:flutter/material.dart';

/// Semantic text theme with 9 tokens covering all UI needs.
///
/// ```
/// Token          Size   Weight       Usage
/// ─────────────  ────   ──────────   ──────────────
/// headlineMedium  24    Bold         Screen-level titles, hero numbers
/// titleLarge      20    Bold         Section headers, popup titles
/// titleMedium     16    SemiBold     Card titles, sub-section headers
/// titleSmall      14    SemiBold     Subtitle, list item titles
/// bodyMedium      13    Normal       Primary body text, labels
/// bodySmall       12    Normal       Secondary info, legends
/// labelLarge      12    w600         Tab labels, emphasized small text
/// labelMedium     11    w500         Metadata lines — dates, times
/// labelSmall      10    w500         Chips, badges, status tags
/// ```
abstract final class AppTextTheme {
  AppTextTheme._();

  static const TextTheme lightTextTheme = TextTheme(
    // Screen-level titles, big hero numbers
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
      height: 1.2,
    ),

    // Section headers, popup titles, large values
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.3,
      height: 1.3,
    ),

    // Card titles, dialog amounts, sub-section headers
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),

    // Subtitle text, card names, list item titles
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),

    // Primary body text, dashboard card labels
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.normal,
      height: 1.4,
    ),

    // Secondary info, legends, calendar day headers
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      height: 1.4,
    ),

    // Tab labels, emphasized small text
    labelLarge: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),

    // Metadata lines — dates, times, stop times
    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),

    // Chips, badges, status tags
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.3,
    ),
  );

  /// 9sp — Ultra-compact tags, notification badges.
  static const TextStyle nano = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  /// 8sp — Absolute minimum. Tiny badge labels only.
  static const TextStyle pico = TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    height: 1.2,
  );
}
