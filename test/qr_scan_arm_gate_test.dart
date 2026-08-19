import 'package:flutter_test/flutter_test.dart';
import 'package:school_erp_staff_app/features/qr_attendance/presentation/qr_scanner_controller.dart';

/// The re-arm rule is the one part of the scanner that must not be improvised: a card
/// held in front of the lens decodes ~30×/second and a naive debounce loops forever.
/// These tests feed synthetic decode streams and assert the accept behaviour.
void main() {
  group('ScanArmGate', () {
    test('a 30fps stream of the same code accepts exactly once', () {
      final gate = ScanArmGate(cooldown: const Duration(seconds: 3));
      final start = DateTime(2026, 8, 2, 9, 0, 0);
      var accepts = 0;

      // 2 seconds of continuous decoding at ~30fps (66 frames).
      for (var i = 0; i < 66; i++) {
        final now = start.add(Duration(milliseconds: i * 33));
        if (gate.offer('SSQR1:STU:3:41:abc', now, active: true)) accepts++;
      }

      expect(accepts, 1, reason: 'A card left in frame must be accepted only once.');
    });

    test('re-accepts only after the card leaves for the re-arm window AND cooldown', () {
      final gate = ScanArmGate(
        rearmWindow: const Duration(milliseconds: 1200),
        cooldown: const Duration(seconds: 3),
      );
      final start = DateTime(2026, 8, 2, 9, 0, 0);

      // First sighting → accept.
      expect(gate.offer('CODE', start, active: true), isTrue);

      // Held continuously for 4s (past the cooldown) but never leaving the frame:
      // still must NOT re-accept, because it was never absent for the re-arm window.
      var reAccepted = false;
      for (var i = 1; i <= 120; i++) {
        final now = start.add(Duration(milliseconds: i * 33)); // ~4s
        if (gate.offer('CODE', now, active: true)) reAccepted = true;
      }
      expect(reAccepted, isFalse, reason: 'Continuous presence must never re-fire.');

      // Now the card leaves and returns after a real gap: last seen was ~3.96s in, so
      // returning at 6s is >1200ms absent (re-armed) and >3s since accept (cooldown).
      final afterGap = start.add(const Duration(seconds: 6));
      expect(gate.offer('CODE', afterGap, active: true), isTrue);
    });

    test('a re-arm gap that is still inside the cooldown is not accepted', () {
      final gate = ScanArmGate(
        rearmWindow: const Duration(milliseconds: 1200),
        cooldown: const Duration(seconds: 3),
      );
      final start = DateTime(2026, 8, 2, 9, 0, 0);

      expect(gate.offer('CODE', start, active: true), isTrue);

      // Card leaves and returns after 1.5s: re-armed (gap > 1200ms) but still inside
      // the 3s cooldown → must be rejected.
      final back = start.add(const Duration(milliseconds: 1500));
      expect(gate.offer('CODE', back, active: true), isFalse);
    });

    test('last-seen still updates while inactive so a held card does not fire on resume', () {
      final gate = ScanArmGate(cooldown: const Duration(seconds: 3));
      final start = DateTime(2026, 8, 2, 9, 0, 0);

      // Decoding while a result sheet is up (active:false) — never accepts, but keeps
      // last-seen fresh.
      for (var i = 0; i < 30; i++) {
        final now = start.add(Duration(milliseconds: i * 33));
        expect(gate.offer('CODE', now, active: false), isFalse);
      }

      // Sheet dismissed; the SAME card is still in frame (only 33ms since last seen)
      // → must not fire because it never left for the re-arm window.
      final resume = start.add(const Duration(milliseconds: 30 * 33 + 33));
      expect(gate.offer('CODE', resume, active: true), isFalse);
    });

    test('different codes are independent', () {
      final gate = ScanArmGate(cooldown: const Duration(seconds: 3));
      final t = DateTime(2026, 8, 2, 9, 0, 0);
      expect(gate.offer('A', t, active: true), isTrue);
      expect(gate.offer('B', t.add(const Duration(milliseconds: 33)), active: true), isTrue);
    });
  });
}
