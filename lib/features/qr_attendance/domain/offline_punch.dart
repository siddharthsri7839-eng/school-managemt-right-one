// Offline-queue types for the QR scanner (plan §P3).
//
// A gate scanner at 08:00 on school wifi *will* drop its connection. When it does,
// a scan of a signed card can still be captured: the signed token embeds the
// type + id, so the app derives them locally and queues a punch to flush later. The
// server re-validates the queued punch by id on flush exactly as it would an online
// one — the local parse is only a lookup key, never a trust decision.

/// A signed attendance token: `SSQR1:STU|STF:<school>:<id>:<sig>`.
///
/// The app can read the type + id without the APP_KEY (it cannot forge or verify the
/// signature — that stays a server concern). Plain codes (bare admission numbers)
/// return null here and simply cannot be queued offline.
class SignedToken {
  final String type; // 'student' | 'staff'
  final int id;
  const SignedToken(this.type, this.id);

  static SignedToken? tryParse(String code) {
    final parts = code.trim().split(':');
    if (parts.length != 5 || parts[0] != 'SSQR1') return null;
    final typeCode = parts[1];
    final id = int.tryParse(parts[3]);
    if (id == null) return null;
    if (typeCode == 'STU') return SignedToken('student', id);
    if (typeCode == 'STF') return SignedToken('staff', id);
    return null;
  }
}

/// One queued punch waiting for connectivity.
class PendingPunch {
  final String type;
  final int id;
  final String? status;
  final DateTime scannedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool isMocked;
  final String? deviceUuid;

  const PendingPunch({
    required this.type,
    required this.id,
    required this.status,
    required this.scannedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMocked,
    required this.deviceUuid,
  });

  /// True when this entry can no longer be a valid "today" punch (client-side
  /// pre-filter; the server is the authority and rejects a stale scanned_at too).
  bool isStale(DateTime now) {
    final s = scannedAt.toLocal();
    return s.year != now.year || s.month != now.month || s.day != now.day;
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'status': status,
        'scanned_at': scannedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'is_mocked': isMocked,
        'device_uuid': deviceUuid,
      };

  factory PendingPunch.fromJson(Map<String, dynamic> j) => PendingPunch(
        type: '${j['type']}',
        id: (j['id'] as num).toInt(),
        status: j['status']?.toString(),
        scannedAt: DateTime.tryParse('${j['scanned_at']}') ?? DateTime.now(),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        isMocked: j['is_mocked'] == true,
        deviceUuid: j['device_uuid']?.toString(),
      );
}

/// Outcome of a flush attempt, for a one-line summary to the operator.
class FlushResult {
  final int sent;
  final int droppedStale;
  final int rejected;
  final int remaining;
  const FlushResult({
    required this.sent,
    required this.droppedStale,
    required this.rejected,
    required this.remaining,
  });

  bool get didAnything => sent > 0 || droppedStale > 0 || rejected > 0;
}
