// Typed models for the Gate tab — the guard's phone as a gate terminal.
//
// Mirrors `Api/V1/Staff/GatePassController` (config / verify / commit / out-now).
// The backend re-derives every allow/deny decision from the raw scanned code, so
// nothing here is trusted for security — these models exist only to render the
// answer and drive the local flow.

/// Per-school gate configuration plus this operator's capabilities.
class GateConfig {
  final bool enabled;
  final List<String> gates;
  final bool canVerify;
  final bool canManage;
  final String schoolTimezone;
  final int outNow;

  const GateConfig({
    required this.enabled,
    required this.gates,
    required this.canVerify,
    required this.canManage,
    required this.schoolTimezone,
    required this.outNow,
  });

  factory GateConfig.fromJson(Map<String, dynamic> j) => GateConfig(
        enabled: j['enabled'] == true,
        gates: ((j['gates'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        canVerify: j['can_verify'] == true,
        canManage: j['can_manage'] == true,
        schoolTimezone: '${j['school_timezone'] ?? 'UTC'}',
        outNow: (j['out_now'] as num?)?.toInt() ?? 0,
      );
}

/// Who the child may be handed to. The block that matters legally.
class GateEscort {
  final String? name;
  final String? relation;
  final String? phone;
  final String? idProof;
  final String? photoUrl;

  const GateEscort({
    this.name,
    this.relation,
    this.phone,
    this.idProof,
    this.photoUrl,
  });

  bool get isPresent => (name ?? '').trim().isNotEmpty;

  factory GateEscort.fromJson(Map<String, dynamic> j) => GateEscort(
        name: j['name']?.toString(),
        relation: j['relation']?.toString(),
        phone: j['phone']?.toString(),
        idProof: j['id_proof']?.toString(),
        photoUrl: j['photo_url']?.toString(),
      );
}

/// The pass as the gate needs to see it.
class GatePassBrief {
  final int id;
  final String passNo;
  final String status;
  final String statusLabel;
  final String type;
  final String name;
  final String sub;
  final String? identifier;
  final String? photoUrl;
  final String reason;
  final String? gate;
  final String? expectedOut;
  final String? gateOutAt;
  final String? gateInAt;
  final bool returning;
  final GateEscort? escort;

  const GatePassBrief({
    required this.id,
    required this.passNo,
    required this.status,
    required this.statusLabel,
    required this.type,
    required this.name,
    required this.sub,
    required this.identifier,
    required this.photoUrl,
    required this.reason,
    required this.gate,
    required this.expectedOut,
    required this.gateOutAt,
    required this.gateInAt,
    required this.returning,
    required this.escort,
  });

  bool get isStudent => type == 'student_exit';

  factory GatePassBrief.fromJson(Map<String, dynamic> j) => GatePassBrief(
        id: (j['id'] as num?)?.toInt() ?? 0,
        passNo: '${j['pass_no'] ?? ''}',
        status: '${j['status'] ?? ''}',
        statusLabel: '${j['status_label'] ?? ''}',
        type: '${j['type'] ?? ''}',
        name: '${j['name'] ?? ''}',
        sub: '${j['sub'] ?? ''}',
        identifier: j['identifier']?.toString(),
        photoUrl: j['photo_url']?.toString(),
        reason: '${j['reason'] ?? ''}',
        gate: j['gate']?.toString(),
        expectedOut: j['expected_out']?.toString(),
        gateOutAt: j['gate_out_at']?.toString(),
        gateInAt: j['gate_in_at']?.toString(),
        returning: j['returning'] == true,
        escort: j['escort'] is Map
            ? GateEscort.fromJson((j['escort'] as Map).cast<String, dynamic>())
            : null,
      );
}

/// The gate's answer. Deliberately one verdict, one machine reason and one
/// sentence — never something the guard has to interpret.
class GateDecision {
  /// 'allow' | 'deny'
  final String decision;

  /// 'out' | 'in' | null
  final String? action;

  /// Stable machine reason on a denial (`no_pass_today`, `not_approved`, …).
  final String? reason;

  final String message;
  final GatePassBrief? pass;

  /// True once the crossing has actually been recorded.
  final bool committed;

  final int outNow;

  const GateDecision({
    required this.decision,
    required this.action,
    required this.reason,
    required this.message,
    required this.pass,
    required this.committed,
    required this.outNow,
  });

  bool get isAllow => decision == 'allow';
  bool get isGoingOut => action == 'out';

  factory GateDecision.fromJson(Map<String, dynamic> j) => GateDecision(
        decision: '${j['decision'] ?? 'deny'}',
        action: j['action']?.toString(),
        reason: j['reason']?.toString(),
        message: '${j['message'] ?? ''}',
        pass: j['pass'] is Map
            ? GatePassBrief.fromJson((j['pass'] as Map).cast<String, dynamic>())
            : null,
        committed: j['committed'] == true,
        outNow: (j['out_now'] as num?)?.toInt() ?? 0,
      );

  /// A local-only denial for when the phone cannot reach the server. Kept in the
  /// same shape so the screen has exactly one thing to render.
  factory GateDecision.offline(String message) => GateDecision(
        decision: 'deny',
        action: null,
        reason: 'offline',
        message: message,
        pass: null,
        committed: false,
        outNow: -1,
      );
}

/// One person currently off campus. This is the fire-drill list.
class GateOutEntry {
  final int id;
  final String passNo;
  final String name;
  final String sub;
  final String reason;
  final DateTime? outAt;
  final bool returning;

  const GateOutEntry({
    required this.id,
    required this.passNo,
    required this.name,
    required this.sub,
    required this.reason,
    required this.outAt,
    required this.returning,
  });

  factory GateOutEntry.fromJson(Map<String, dynamic> j) => GateOutEntry(
        id: (j['id'] as num?)?.toInt() ?? 0,
        passNo: '${j['pass_no'] ?? ''}',
        name: '${j['name'] ?? ''}',
        sub: '${j['sub'] ?? ''}',
        reason: '${j['reason'] ?? ''}',
        outAt: DateTime.tryParse('${j['out_at'] ?? ''}')?.toLocal(),
        returning: j['returning'] == true,
      );
}
