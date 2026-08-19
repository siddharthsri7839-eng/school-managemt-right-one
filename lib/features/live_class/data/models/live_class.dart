/// A scheduled or in-progress live class, as returned by
/// `GET /staff/live-classes`.
class LiveClass {
  final int id;
  final String title;
  final String? description;
  final String? className;
  final String? sectionName;
  final String? subjectName;
  final String? teacherName;
  final int? schoolClassId;
  final int? sectionId;
  final int? subjectId;
  final String provider;
  final String status;
  final DateTime? startTime;
  final int durationMinutes;
  final String? meetingLink;
  final String? recordingLink;
  final bool isRecurring;

  const LiveClass({
    required this.id,
    required this.title,
    required this.provider,
    required this.status,
    required this.durationMinutes,
    required this.isRecurring,
    this.description,
    this.className,
    this.sectionName,
    this.subjectName,
    this.teacherName,
    this.schoolClassId,
    this.sectionId,
    this.subjectId,
    this.startTime,
    this.meetingLink,
    this.recordingLink,
  });

  factory LiveClass.fromJson(Map<String, dynamic> json) => LiveClass(
        id: json['id'] as int,
        title: (json['title'] ?? '') as String,
        description: json['description'] as String?,
        className: json['class_name'] as String?,
        sectionName: json['section_name'] as String?,
        subjectName: json['subject_name'] as String?,
        teacherName: json['teacher_name'] as String?,
        schoolClassId: json['school_class_id'] as int?,
        sectionId: json['section_id'] as int?,
        subjectId: json['subject_id'] as int?,
        provider: (json['provider'] ?? '') as String,
        status: (json['status'] ?? 'scheduled') as String,
        startTime: json['start_time'] != null
            ? DateTime.tryParse(json['start_time'] as String)?.toLocal()
            : null,
        durationMinutes: (json['duration_minutes'] ?? 0) as int,
        meetingLink: json['meeting_link'] as String?,
        recordingLink: json['recording_link'] as String?,
        isRecurring: (json['is_recurring'] ?? false) as bool,
      );

  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended';

  String get whereLabel {
    final parts = [className, sectionName].where((p) => p != null && p.isNotEmpty);
    return parts.isEmpty ? '' : parts.join(' · ');
  }
}

/// One provider the school has enabled, from `GET /staff/live-classes/form-data`.
///
/// `needsLink` mirrors the web form's `data-needs-link`: only providers that
/// cannot mint their own meeting (external link) ask the teacher for a URL.
class MeetingProviderOption {
  final String key;
  final String label;
  final bool needsLink;

  const MeetingProviderOption({
    required this.key,
    required this.label,
    required this.needsLink,
  });

  factory MeetingProviderOption.fromJson(Map<String, dynamic> json) {
    final key = (json['key'] ?? '') as String;
    return MeetingProviderOption(
      key: key,
      label: (json['label'] ?? json['name'] ?? key) as String,
      // Be tolerant about which flag the backend schema exposes — fall back to
      // the one provider that definitionally needs a pasted link.
      needsLink: (json['needs_link'] ?? json['needs_meeting_link'] ?? key == 'external_link') as bool,
    );
  }
}

/// A named id pair for the class/section/subject cascade.
class NamedOption {
  final int id;
  final String name;

  const NamedOption({required this.id, required this.name});

  factory NamedOption.fromJson(Map<String, dynamic> json) => NamedOption(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
      );
}

/// How the host should join, from `POST /staff/live-classes/{id}/start`.
class JoinContext {
  /// `embed` (our own room page) or `redirect` (hand off to the provider).
  final String mode;
  final String url;
  final String provider;

  const JoinContext({
    required this.mode,
    required this.url,
    required this.provider,
  });

  factory JoinContext.fromJson(Map<String, dynamic> json) => JoinContext(
        mode: (json['join_mode'] ?? 'embed') as String,
        url: (json['join_url'] ?? '') as String,
        provider: (json['provider'] ?? '') as String,
      );
}
