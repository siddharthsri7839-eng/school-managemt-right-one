import 'package:flutter_test/flutter_test.dart';
import 'package:school_erp_staff_app/features/qr_attendance/domain/offline_punch.dart';

/// The offline-queue trust boundary: only a SIGNED token can be identified without
/// the server, and a queued punch that is no longer "today" must be recognised as
/// stale so the flush drops it (the server would reject it anyway).
void main() {
  group('SignedToken.tryParse', () {
    test('parses a signed student token to type + id', () {
      final t = SignedToken.tryParse('SSQR1:STU:3:41:abc123def456');
      expect(t, isNotNull);
      expect(t!.type, 'student');
      expect(t.id, 41);
    });

    test('parses a signed staff token', () {
      final t = SignedToken.tryParse('SSQR1:STF:3:9:sigsigsig');
      expect(t!.type, 'staff');
      expect(t.id, 9);
    });

    test('rejects a plain admission number (cannot be queued offline)', () {
      expect(SignedToken.tryParse('ADM-2026-0041'), isNull);
    });

    test('rejects a malformed / wrong-arity token', () {
      expect(SignedToken.tryParse('SSQR1:STU:3:41'), isNull); // 4 parts
      expect(SignedToken.tryParse('SSQR1:XXX:3:41:sig'), isNull); // bad type
      expect(SignedToken.tryParse('SSQR1:STU:3:notanumber:sig'), isNull);
    });
  });

  group('PendingPunch.isStale', () {
    PendingPunch at(DateTime when) => PendingPunch(
          type: 'student',
          id: 1,
          status: null,
          scannedAt: when,
          latitude: null,
          longitude: null,
          accuracy: null,
          isMocked: false,
          deviceUuid: null,
        );

    test('a punch scanned today is not stale', () {
      final now = DateTime(2026, 8, 2, 9, 0);
      expect(at(DateTime(2026, 8, 2, 8, 15)).isStale(now), isFalse);
    });

    test('a punch from yesterday is stale', () {
      final now = DateTime(2026, 8, 2, 9, 0);
      expect(at(DateTime(2026, 8, 1, 8, 15)).isStale(now), isTrue);
    });

    test('json round-trips', () {
      final p = at(DateTime(2026, 8, 2, 8, 15));
      final back = PendingPunch.fromJson(p.toJson());
      expect(back.id, p.id);
      expect(back.scannedAt, p.scannedAt);
    });
  });
}
