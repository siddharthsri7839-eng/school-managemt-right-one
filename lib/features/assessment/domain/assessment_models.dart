// Domain models for the Continuous Assessment module (staff app).
//
// Mirrors the JSON returned by Api/V1/Staff/Assessment* controllers. Reports
// analytics stay as raw maps (deeply nested, render-only) like the PTM module;
// the core entities below are typed for the CRUD + mark-entry flows.

int? _asInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
double? _asDouble(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

/// A {value,label} pair for a dropdown (assessment type, frequency, etc.).
class EnumOption {
  final String value;
  final String label;
  const EnumOption({required this.value, required this.label});

  factory EnumOption.fromJson(Map<String, dynamic> j) =>
      EnumOption(value: '${j['value']}', label: '${j['label']}');
}

/// A {id,name} pair for class / subject / section dropdowns.
class NamedOption {
  final int id;
  final String name;
  const NamedOption({required this.id, required this.name});

  factory NamedOption.fromJson(Map<String, dynamic> j) =>
      NamedOption(id: _asInt(j['id']) ?? 0, name: '${j['name'] ?? ''}');
}

/// What the current user may do in the module (drives UI gating).
class AssessmentCapabilities {
  final bool manage;
  final bool enter;
  final bool publish;
  final bool report;
  const AssessmentCapabilities({
    this.manage = false,
    this.enter = false,
    this.publish = false,
    this.report = false,
  });

  factory AssessmentCapabilities.fromJson(Map<String, dynamic>? j) => AssessmentCapabilities(
        manage: j?['manage'] == true,
        enter: j?['enter'] == true,
        publish: j?['publish'] == true,
        report: j?['report'] == true,
      );
}

/// One row in the assessments list / dashboard recents.
class AssessmentSummary {
  final int id;
  final String title;
  final String? type;
  final String? typeLabel;
  final String? subject;
  final int? subjectId;
  final String? className;
  final int? classId;
  final String? section;
  final int? sectionId;
  final double? totalMarks;
  final String? frequency;
  final int sittings;

  const AssessmentSummary({
    required this.id,
    required this.title,
    this.type,
    this.typeLabel,
    this.subject,
    this.subjectId,
    this.className,
    this.classId,
    this.section,
    this.sectionId,
    this.totalMarks,
    this.frequency,
    this.sittings = 0,
  });

  factory AssessmentSummary.fromJson(Map<String, dynamic> j) => AssessmentSummary(
        id: _asInt(j['id']) ?? 0,
        title: '${j['title'] ?? ''}',
        type: j['type'] as String?,
        typeLabel: j['type_label'] as String?,
        subject: j['subject'] as String?,
        subjectId: _asInt(j['subject_id']),
        className: j['class'] as String?,
        classId: _asInt(j['class_id']),
        section: j['section'] as String?,
        sectionId: _asInt(j['section_id']),
        totalMarks: _asDouble(j['total_marks']),
        frequency: j['frequency'] as String?,
        sittings: _asInt(j['sittings']) ?? 0,
      );
}

/// One dated sitting under an assessment.
class OccurrenceRow {
  final int id;
  final String? scheduledDate;
  final String? status;
  final String? statusLabel;
  final bool isLocked;
  final int enteredCount;
  final String? publishedAt;

  const OccurrenceRow({
    required this.id,
    this.scheduledDate,
    this.status,
    this.statusLabel,
    this.isLocked = false,
    this.enteredCount = 0,
    this.publishedAt,
  });

  factory OccurrenceRow.fromJson(Map<String, dynamic> j) => OccurrenceRow(
        id: _asInt(j['id']) ?? 0,
        scheduledDate: j['scheduled_date'] as String?,
        status: j['status'] as String?,
        statusLabel: j['status_label'] as String?,
        isLocked: j['is_locked'] == true,
        enteredCount: _asInt(j['entered_count']) ?? 0,
        publishedAt: j['published_at'] as String?,
      );
}

/// Full assessment detail (header + sittings).
class AssessmentDetail {
  final int id;
  final String title;
  final String? type;
  final String? typeLabel;
  final String? subject;
  final int? subjectId;
  final String? className;
  final int? classId;
  final String? section;
  final int? sectionId;
  final double? totalMarks;
  final double? passingMarks;
  final String? frequency;
  final String? conductedVia;
  final String? instructions;
  final String? creatorName;
  final bool canUpdate;
  final bool canDelete;
  final bool hasMarks;
  final List<OccurrenceRow> occurrences;

  const AssessmentDetail({
    required this.id,
    required this.title,
    this.type,
    this.typeLabel,
    this.subject,
    this.subjectId,
    this.className,
    this.classId,
    this.section,
    this.sectionId,
    this.totalMarks,
    this.passingMarks,
    this.frequency,
    this.conductedVia,
    this.instructions,
    this.creatorName,
    this.canUpdate = false,
    this.canDelete = false,
    this.hasMarks = false,
    this.occurrences = const [],
  });

  factory AssessmentDetail.fromJson(Map<String, dynamic> j) {
    final can = (j['can'] as Map?)?.cast<String, dynamic>();
    return AssessmentDetail(
      id: _asInt(j['id']) ?? 0,
      title: '${j['title'] ?? ''}',
      type: j['type'] as String?,
      typeLabel: j['type_label'] as String?,
      subject: j['subject'] as String?,
      subjectId: _asInt(j['subject_id']),
      className: j['class'] as String?,
      classId: _asInt(j['class_id']),
      section: j['section'] as String?,
      sectionId: _asInt(j['section_id']),
      totalMarks: _asDouble(j['total_marks']),
      passingMarks: _asDouble(j['passing_marks']),
      frequency: j['frequency'] as String?,
      conductedVia: j['conducted_via'] as String?,
      instructions: j['instructions'] as String?,
      creatorName: j['creator_name'] as String?,
      canUpdate: can?['update'] == true,
      canDelete: can?['delete'] == true,
      hasMarks: can?['locked'] == true,
      occurrences: ((j['occurrences'] as List?) ?? [])
          .map((o) => OccurrenceRow.fromJson((o as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// One student row in the mark-entry grid.
class MarkGridStudent {
  final int studentId;
  final String name;
  final String? rollNo;
  double? marks;
  String attendance; // present | absent
  double? percentage;

  MarkGridStudent({
    required this.studentId,
    required this.name,
    this.rollNo,
    this.marks,
    this.attendance = 'present',
    this.percentage,
  });

  factory MarkGridStudent.fromJson(Map<String, dynamic> j) => MarkGridStudent(
        studentId: _asInt(j['student_id']) ?? 0,
        name: '${j['name'] ?? ''}',
        rollNo: j['roll_no']?.toString(),
        marks: _asDouble(j['marks']),
        attendance: (j['attendance'] as String?) ?? 'present',
        percentage: _asDouble(j['percentage']),
      );
}

/// The whole mark-entry grid for a sitting.
class MarkGrid {
  final int occurrenceId;
  final String? scheduledDate;
  final String? status;
  final String? statusLabel;
  final bool isLocked;
  final String assessmentTitle;
  final String? subject;
  final String? className;
  final String? section;
  final double? totalMarks;
  final double? passingMarks;
  final bool canEnter;
  final bool canPublish;
  final List<MarkGridStudent> students;

  const MarkGrid({
    required this.occurrenceId,
    this.scheduledDate,
    this.status,
    this.statusLabel,
    this.isLocked = false,
    required this.assessmentTitle,
    this.subject,
    this.className,
    this.section,
    this.totalMarks,
    this.passingMarks,
    this.canEnter = false,
    this.canPublish = false,
    this.students = const [],
  });

  factory MarkGrid.fromJson(Map<String, dynamic> j) {
    final occ = (j['occurrence'] as Map).cast<String, dynamic>();
    final a = (j['assessment'] as Map).cast<String, dynamic>();
    return MarkGrid(
      occurrenceId: _asInt(occ['id']) ?? 0,
      scheduledDate: occ['scheduled_date'] as String?,
      status: occ['status'] as String?,
      statusLabel: occ['status_label'] as String?,
      isLocked: occ['is_locked'] == true,
      assessmentTitle: '${a['title'] ?? ''}',
      subject: a['subject'] as String?,
      className: a['class'] as String?,
      section: a['section'] as String?,
      totalMarks: _asDouble(a['total_marks']),
      passingMarks: _asDouble(a['passing_marks']),
      canEnter: j['can_enter'] == true,
      canPublish: j['can_publish'] == true,
      students: ((j['students'] as List?) ?? [])
          .map((s) => MarkGridStudent.fromJson((s as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
