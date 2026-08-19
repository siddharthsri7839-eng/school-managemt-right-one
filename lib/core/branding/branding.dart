import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'terminology.dart';

/// Runtime branding for the staff app, built from the backend `/branding`
/// payload — or from [Branding.fallback] (the values the app shipped with) when
/// offline, on first launch, or when dynamic branding is disabled server-side.
///
/// Every field is parsed defensively: [Branding.fromJson] substitutes the
/// fallback value for ANY missing/invalid field, so the app can never render
/// with a hole (backend docs/dynamic-branding-plan.md §0 N1, §5.2). Dart mirror
/// of the server's `BrandingService` contract — identical across all 3 apps.
@immutable
class Branding {
  final int schemaVersion;
  final bool dynamicEnabled;
  final String appName;
  final String? logoUrl;

  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color secondary;
  final Color tertiary;
  final Color accent; // staff app uses this (FAB, accents)
  final Color onPrimary;
  final Color onSecondary;

  /// Academic wording (schema v2). Independent of [dynamicEnabled] — a school
  /// may relabel Class→Year while keeping the stock theme, so [effective]
  /// must never collapse this together with the colors.
  final Terminology terminology;

  const Branding({
    required this.schemaVersion,
    required this.dynamicEnabled,
    required this.appName,
    required this.logoUrl,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.tertiary,
    required this.accent,
    required this.onPrimary,
    required this.onSecondary,
    this.terminology = const Terminology.fallback(),
  });

  /// Compile-time fallback — the exact Heritage values the staff app shipped with.
  const Branding.fallback()
      : schemaVersion = 1,
        dynamicEnabled = false,
        appName = AppConfig.appName,
        logoUrl = null,
        primary = const Color(0xFF1A365D),
        primaryLight = const Color(0xFF2A4A7F),
        primaryDark = const Color(0xFF0F2341),
        secondary = const Color(0xFF9B2C2C),
        tertiary = const Color(0xFFD4AF37),
        accent = const Color(0xFFF37021),
        onPrimary = const Color(0xFFFFFFFF),
        onSecondary = const Color(0xFFFFFFFF),
        terminology = const Terminology.fallback();

  /// Parse a `/branding` payload. Never throws — falls back per field.
  factory Branding.fromJson(Map<String, dynamic> json) {
    const fb = Branding.fallback();
    final colors = (json['colors'] is Map)
        ? Map<String, dynamic>.from(json['colors'] as Map)
        : const <String, dynamic>{};

    return Branding(
      schemaVersion: _int(json['schema_version'], fb.schemaVersion),
      dynamicEnabled: json['branding_dynamic_enabled'] == true,
      appName: _name(json['app_name'], fb.appName),
      logoUrl: _url(json['logo_url']),
      primary: _color(colors['primary'], fb.primary),
      primaryLight: _color(colors['primaryLight'], fb.primaryLight),
      primaryDark: _color(colors['primaryDark'], fb.primaryDark),
      secondary: _color(colors['secondary'], fb.secondary),
      tertiary: _color(colors['tertiary'], fb.tertiary),
      accent: _color(colors['accent'], fb.accent),
      onPrimary: _color(colors['onPrimary'], fb.onPrimary),
      onSecondary: _color(colors['onSecondary'], fb.onSecondary),
      terminology: Terminology.fromJson(json),
    );
  }

  /// When dynamic branding is OFF, the app looks exactly as it shipped (N5) —
  /// EXCEPT the academic wording, which has its own server-side kill switch
  /// (already honoured inside [Terminology.fromJson]) and must survive here.
  Branding get effective => dynamicEnabled
      ? this
      : const Branding.fallback().copyWith(terminology: terminology);

  Branding copyWith({Terminology? terminology}) => Branding(
        schemaVersion: schemaVersion,
        dynamicEnabled: dynamicEnabled,
        appName: appName,
        logoUrl: logoUrl,
        primary: primary,
        primaryLight: primaryLight,
        primaryDark: primaryDark,
        secondary: secondary,
        tertiary: tertiary,
        accent: accent,
        onPrimary: onPrimary,
        onSecondary: onSecondary,
        terminology: terminology ?? this.terminology,
      );

  // ── Defensive parsers ──────────────────────────────────────────────────────

  static int _int(dynamic v, int fb) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fb;
    return fb;
  }

  static String _name(dynamic v, String fb) {
    if (v is String) {
      final t = v.trim();
      if (t.isNotEmpty) return t.length > 40 ? t.substring(0, 40) : t;
    }
    return fb;
  }

  static String? _url(dynamic v) {
    if (v is String) {
      final t = v.trim();
      if (t.startsWith('http://') || t.startsWith('https://')) return t;
    }
    return null;
  }

  /// Parse `#RRGGBB` (or `RRGGBB`) → opaque [Color]. Malformed → [fb], no throw.
  static Color _color(dynamic v, Color fb) {
    if (v is String) {
      final m = RegExp(r'^#?([0-9A-Fa-f]{6})$').firstMatch(v.trim());
      if (m != null) {
        return Color(int.parse('FF${m.group(1)}', radix: 16));
      }
    }
    return fb;
  }
}
