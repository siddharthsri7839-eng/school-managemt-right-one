// Typed models for the QR / barcode attendance scanner ("Plan B").
//
// Mirrors the JSON returned by `Api/V1/Staff/QrAttendanceController`
// (config / resolve / punch). The backend re-derives every security decision, so
// these models are purely for display + local flow control.

/// Per-school scanner configuration plus this operator's capabilities.
class QrScannerConfig {
  final bool autoAttendance;
  final int scanCooldownSeconds;
  final bool requireSignedToken;
  final List<String> allowedFormats;
  final String schoolTimezone;

  /// 'gate' (whole-school operator) or 'classroom' (section-scoped teacher).
  final String scanMode;
  final bool canMarkStudents;
  final bool canMarkStaff;

  final bool geofenceRequired;
  final bool deviceBindingRequired;

  /// Signed-cards-only + geofence + device — the "legal proof" profile.
  final bool highAssurance;

  const QrScannerConfig({
    required this.autoAttendance,
    required this.scanCooldownSeconds,
    required this.requireSignedToken,
    required this.allowedFormats,
    required this.schoolTimezone,
    required this.scanMode,
    required this.canMarkStudents,
    required this.canMarkStaff,
    required this.geofenceRequired,
    required this.deviceBindingRequired,
    required this.highAssurance,
  });

  bool get isGate => scanMode == 'gate';

  factory QrScannerConfig.fromJson(Map<String, dynamic> j) => QrScannerConfig(
        autoAttendance: j['auto_attendance'] == true,
        scanCooldownSeconds: (j['scan_cooldown_seconds'] as num?)?.toInt() ?? 3,
        requireSignedToken: j['require_signed_token'] == true,
        allowedFormats: ((j['allowed_formats'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        schoolTimezone: '${j['school_timezone'] ?? 'UTC'}',
        scanMode: '${j['scan_mode'] ?? 'classroom'}',
        canMarkStudents: j['can_mark_students'] == true,
        canMarkStaff: j['can_mark_staff'] == true,
        geofenceRequired: j['geofence_required'] == true,
        deviceBindingRequired: j['device_binding_required'] == true,
        highAssurance: j['high_assurance'] == true,
      );
}

/// A resolved scan: who the card belongs to + today's attendance state.
class QrScanProfile {
  final String type; // 'student' | 'staff'
  final int id;
  final String name;
  final String? code;
  final String subtitle;
  final String? photoUrl;
  final bool alreadyComplete;
  final String? todayIn;
  final String? todayOut;
  final String? todayStatus;

  /// Whether THIS operator may mark THIS record (scope / staff-perm aware).
  final bool canMark;

  const QrScanProfile({
    required this.type,
    required this.id,
    required this.name,
    required this.code,
    required this.subtitle,
    required this.photoUrl,
    required this.alreadyComplete,
    required this.todayIn,
    required this.todayOut,
    required this.todayStatus,
    required this.canMark,
  });

  bool get isStudent => type == 'student';

  factory QrScanProfile.fromJson(Map<String, dynamic> j) {
    final today = (j['today'] as Map?)?.cast<String, dynamic>() ?? const {};
    return QrScanProfile(
      type: '${j['type'] ?? 'student'}',
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: '${j['name'] ?? ''}',
      code: j['code']?.toString(),
      subtitle: '${j['subtitle'] ?? ''}',
      photoUrl: j['photo_url']?.toString(),
      alreadyComplete: j['already_complete'] == true,
      todayIn: today['in']?.toString(),
      todayOut: today['out']?.toString(),
      todayStatus: today['status']?.toString(),
      canMark: j['can_mark'] == true,
    );
  }
}

/// Outcome of a successful punch.
class QrPunchResult {
  final String result; // 'marked_in' | 'marked_out'
  final String action; // 'in' | 'out'
  final String? time;
  final String message;

  const QrPunchResult({
    required this.result,
    required this.action,
    required this.time,
    required this.message,
  });

  bool get isIn => action == 'in';

  factory QrPunchResult.fromJson(Map<String, dynamic> j) => QrPunchResult(
        result: '${j['result'] ?? ''}',
        action: '${j['action'] ?? ''}',
        time: j['time']?.toString(),
        message: '${j['message'] ?? ''}',
      );
}

/// A business-level denial from resolve/punch (HTTP 422, `status:false`), carrying
/// the backend's stable machine `reason` so the UI can colour the outcome without
/// string-matching the human message.
class QrScanException implements Exception {
  final String reason;
  final String message;
  const QrScanException(this.reason, this.message);

  @override
  String toString() => message;
}
