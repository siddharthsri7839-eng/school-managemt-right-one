import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_erp_staff_app/core/branding/branding.dart';

void main() {
  group('Branding.fromJson resilience (staff)', () {
    test('parses a complete valid payload incl. accent', () {
      final b = Branding.fromJson({
        'branding_dynamic_enabled': true,
        'app_name': 'Staff Heritage',
        'logo_url': 'https://example.com/app_logo.png',
        'colors': {'primary': '#0A7E3D', 'accent': '#FF8800'},
      });
      expect(b.appName, 'Staff Heritage');
      expect(b.primary, const Color(0xFF0A7E3D));
      expect(b.accent, const Color(0xFFFF8800));
    });

    test('malformed hex → that token falls back, others survive', () {
      const fb = Branding.fallback();
      final b = Branding.fromJson({
        'branding_dynamic_enabled': true,
        'colors': {'primary': '#00FF00', 'accent': 'NOPE'},
      });
      expect(b.primary, const Color(0xFF00FF00));
      expect(b.accent, fb.accent);
    });

    test('garbage types never throw', () {
      final b = Branding.fromJson({'app_name': 123, 'colors': 'x'});
      const fb = Branding.fallback();
      expect(b.appName, fb.appName);
      expect(b.primary, fb.primary);
    });

    test('effective collapses to fallback when dynamic disabled', () {
      final b = Branding.fromJson({
        'branding_dynamic_enabled': false,
        'app_name': 'Custom',
        'colors': {'accent': '#00FF00'},
      });
      const fb = Branding.fallback();
      expect(b.effective.accent, fb.accent);
      expect(b.effective.appName, fb.appName);
    });
  });
}
