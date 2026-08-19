// lib/features/online_exam/domain/online_exam_models.dart
//
// Types for the teacher's side of Online Exams. Shapes mirror the staff API
// (Api\V1\Staff\OnlineExamController + OnlineExamBuilderController) 1:1.
//
// Every parse is defensive about nulls and numeric types: the same endpoint
// serves papers built before P2 (no sections, no schedules) and papers built
// yesterday, and a hard cast on a legacy row is how a list screen dies on one
// bad record.

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v, [String fallback = '—']) => v?.toString() ?? fallback;

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic v) =>
    ((v as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

/// The three delivery modes. Kept as a plain string with helpers rather than an
/// enum: a tenth mode added server-side must not crash a shipped app.
class ExamKind {
  static const exam = 'exam';
  static const quiz = 'quiz';
  static const practice = 'practice';

  static String label(String type) => switch (type) {
        quiz => 'Quiz',
        practice => 'Practice Set',
        _ => 'Exam',
      };
}

/// One paper in the teacher's list.
class ExamPaper {
  final int id;
  final String title;
  final String type;
  final String publishState;
  final bool isPublished;

  /// upcoming | active | completed — derived from the clock server-side.
  final String windowState;

  final String className;
  final String? section;
  final String subject;
  final int? schoolClassId;
  final int? subjectId;

  /// Practice papers obey no clock and no window; the server sends null rather
  /// than a duration and deadline they do not honour.
  final bool isTimed;
  final int? duration;
  final DateTime? startTime;
  final DateTime? endTime;

  final double totalMarks;
  final int questionCount;

  const ExamPaper({
    required this.id,
    required this.title,
    required this.type,
    required this.publishState,
    required this.isPublished,
    required this.windowState,
    required this.className,
    required this.subject,
    required this.isTimed,
    required this.totalMarks,
    required this.questionCount,
    this.section,
    this.schoolClassId,
    this.subjectId,
    this.duration,
    this.startTime,
    this.endTime,
  });

  String get kindLabel => ExamKind.label(type);
  bool get isPractice => type == ExamKind.practice;
  bool get isDraft => !isPublished;

  /// What the row should say about timing. Practice never gets a countdown.
  String get windowLabel {
    if (isPractice) return 'Always open · untimed';
    return switch (windowState) {
      'upcoming' => 'Not started yet',
      'completed' => 'Closed',
      _ => 'Open now',
    };
  }

  factory ExamPaper.fromJson(Map<String, dynamic> json) => ExamPaper(
        id: _i(json['id']),
        title: _s(json['title'], 'Untitled'),
        type: _s(json['type'], ExamKind.exam),
        publishState: _s(json['publish_state'], 'published'),
        isPublished: json['is_published'] == true,
        windowState: _s(json['window_state'], 'active'),
        className: _s(json['class']),
        section: json['section']?.toString(),
        subject: _s(json['subject']),
        schoolClassId: (json['school_class_id'] as num?)?.toInt(),
        subjectId: (json['subject_id'] as num?)?.toInt(),
        isTimed: json['is_timed'] != false,
        duration: (json['duration'] as num?)?.toInt(),
        startTime: DateTime.tryParse(json['start_time']?.toString() ?? ''),
        endTime: DateTime.tryParse(json['end_time']?.toString() ?? ''),
        totalMarks: _d(json['total_marks']),
        questionCount: _i(json['question_count']),
      );
}

/// A paper opened on its own — the list row plus its structure.
class ExamPaperDetail {
  final ExamPaper paper;
  final String? instructionsHtml;
  final List<ExamSectionSummary> sections;
  final List<ExamSchedule> schedules;
  final int pendingReview;

  const ExamPaperDetail({
    required this.paper,
    required this.sections,
    required this.schedules,
    required this.pendingReview,
    this.instructionsHtml,
  });

  factory ExamPaperDetail.fromJson(Map<String, dynamic> json) => ExamPaperDetail(
        paper: ExamPaper.fromJson(json),
        instructionsHtml: json['instructions_html']?.toString(),
        sections: _maps(json['sections']).map(ExamSectionSummary.fromJson).toList(),
        schedules: _maps(json['schedules']).map(ExamSchedule.fromJson).toList(),
        pendingReview: _i(json['pending_review']),
      );
}

class ExamSectionSummary {
  final int id;
  final String name;
  final int position;
  final int questionCount;

  const ExamSectionSummary({
    required this.id,
    required this.name,
    required this.position,
    required this.questionCount,
  });

  factory ExamSectionSummary.fromJson(Map<String, dynamic> json) => ExamSectionSummary(
        id: _i(json['id']),
        name: _s(json['name'], 'Section'),
        position: _i(json['position']),
        questionCount: _i(json['question_count']),
      );
}

class ExamSchedule {
  final int id;
  final String? title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? durationMinutes;
  final int? maxAttempts;
  final bool isActive;
  final String state;

  /// Students have already sat it — it may be deactivated but never deleted.
  final bool hasAttempts;

  /// "classId" or "classId:sectionId", the exact shape syncTargets takes back.
  final List<String> targets;
  final List<String> targetLabels;

  const ExamSchedule({
    required this.id,
    required this.isActive,
    required this.state,
    required this.hasAttempts,
    required this.targets,
    this.title,
    this.startsAt,
    this.endsAt,
    this.durationMinutes,
    this.maxAttempts,
    this.targetLabels = const [],
  });

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    // The read endpoint sends target objects; the builder endpoint sends the
    // "classId:sectionId" strings. Accept either so one model serves both.
    final rawTargets = (json['targets'] as List?) ?? const [];
    final strings = <String>[];
    final labels = <String>[];

    for (final t in rawTargets) {
      if (t is Map) {
        final m = t.cast<String, dynamic>();
        final classId = m['school_class_id'];
        final sectionId = m['section_id'];
        strings.add(sectionId == null ? '$classId' : '$classId:$sectionId');
        labels.add(_s(m['label']));
      } else {
        strings.add(t.toString());
      }
    }

    return ExamSchedule(
      id: _i(json['id']),
      title: json['title']?.toString(),
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? ''),
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? ''),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      maxAttempts: (json['max_attempts'] as num?)?.toInt(),
      isActive: json['is_active'] != false,
      state: _s(json['state'], 'active'),
      hasAttempts: json['has_attempts'] == true,
      targets: strings,
      targetLabels: labels,
    );
  }
}

/// One student's sitting, on the results screen.
class ExamAttemptRow {
  final int attemptId;
  final int studentId;
  final String student;
  final int attemptNo;
  final double score;
  final double maxScore;
  final double percentage;
  final String status;
  final String? result;
  final DateTime? submittedAt;

  const ExamAttemptRow({
    required this.attemptId,
    required this.studentId,
    required this.student,
    required this.attemptNo,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.status,
    this.result,
    this.submittedAt,
  });

  /// A written answer holds the whole attempt here until a human marks it.
  bool get awaitingReview => status == 'submitted_pending_review';
  bool get inProgress => status == 'in-progress' || status == 'paused';

  factory ExamAttemptRow.fromJson(Map<String, dynamic> json) => ExamAttemptRow(
        attemptId: _i(json['attempt_id']),
        studentId: _i(json['student_id']),
        student: _s(json['student']),
        attemptNo: _i(json['attempt_no']),
        score: _d(json['score']),
        maxScore: _d(json['max_score']),
        percentage: _d(json['percentage']),
        status: _s(json['status'], 'completed'),
        result: json['result']?.toString(),
        submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      );
}

// ── marking ────────────────────────────────────────────────────────────────

/// A paper with answers waiting on a human, in the marking queue.
class MarkingQueueRow {
  final int examId;
  final String title;
  final String subject;
  final String className;
  final int pending;
  final List<MarkingQueueAttempt> attempts;

  const MarkingQueueRow({
    required this.examId,
    required this.title,
    required this.subject,
    required this.className,
    required this.pending,
    required this.attempts,
  });

  factory MarkingQueueRow.fromJson(Map<String, dynamic> json) => MarkingQueueRow(
        examId: _i(json['exam_id']),
        title: _s(json['title'], 'Untitled'),
        subject: _s(json['subject']),
        className: _s(json['class']),
        pending: _i(json['pending']),
        attempts: _maps(json['attempts']).map(MarkingQueueAttempt.fromJson).toList(),
      );
}

class MarkingQueueAttempt {
  final int attemptId;
  final String student;
  final int pending;

  const MarkingQueueAttempt({
    required this.attemptId,
    required this.student,
    required this.pending,
  });

  factory MarkingQueueAttempt.fromJson(Map<String, dynamic> json) => MarkingQueueAttempt(
        attemptId: _i(json['attempt_id']),
        student: _s(json['student']),
        pending: _i(json['pending']),
      );
}

/// One attempt open for marking.
class AttemptReview {
  final int attemptId;
  final String student;
  final int examId;
  final String? exam;
  final double score;
  final double maxScore;
  final List<PendingAnswer> answers;

  const AttemptReview({
    required this.attemptId,
    required this.student,
    required this.examId,
    required this.score,
    required this.maxScore,
    required this.answers,
    this.exam,
  });

  factory AttemptReview.fromJson(Map<String, dynamic> json) => AttemptReview(
        attemptId: _i(json['attempt_id']),
        student: _s(json['student']),
        examId: _i(json['exam_id']),
        exam: json['exam']?.toString(),
        score: _d(json['score']),
        maxScore: _d(json['max_score']),
        answers: _maps(json['answers']).map(PendingAnswer.fromJson).toList(),
      );
}

/// A written answer awaiting a mark.
class PendingAnswer {
  final int answerId;
  final int questionId;
  final String question;
  final String questionType;
  final String typeLabel;

  /// What the student wrote. Rendered as text — the server hands back a
  /// readable form rather than the raw structured payload.
  final String response;

  final double maxMarks;

  /// The teacher's own model answer. Safe here; never sent to a student.
  final String? rubric;

  const PendingAnswer({
    required this.answerId,
    required this.questionId,
    required this.question,
    required this.questionType,
    required this.typeLabel,
    required this.response,
    required this.maxMarks,
    this.rubric,
  });

  factory PendingAnswer.fromJson(Map<String, dynamic> json) {
    final raw = json['response'];

    return PendingAnswer(
      answerId: _i(json['answer_id']),
      questionId: _i(json['question_id']),
      question: _s(json['question'], ''),
      questionType: _s(json['question_type'], ''),
      typeLabel: _s(json['type_label'], ''),
      // A readable string is the contract, but a legacy row can still carry a
      // map or a list; showing something beats showing "Instance of…".
      response: raw is String ? raw : (raw == null ? '' : raw.toString()),
      maxMarks: _d(json['max_marks']),
      rubric: json['rubric']?.toString(),
    );
  }
}

/// What awarding a mark did to the attempt.
class AwardOutcome {
  final double score;
  final double maxScore;
  final double percentage;
  final String status;

  /// Answers still pending on this attempt. Zero means it is finished.
  final int remaining;
  final String message;

  const AwardOutcome({
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.status,
    required this.remaining,
    required this.message,
  });

  factory AwardOutcome.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data']);

    return AwardOutcome(
      score: _d(data['score']),
      maxScore: _d(data['max_score']),
      percentage: _d(data['percentage']),
      status: _s(data['status'], 'completed'),
      remaining: _i(data['remaining']),
      message: _s(json['message'], 'Marked.'),
    );
  }
}

// ── builder ────────────────────────────────────────────────────────────────

/// The whole paper as the authoring screens need it.
class ExamBuilderState {
  final int id;
  final String title;
  final String type;
  final String publishState;
  final int? subjectId;
  final int durationMinutes;
  final int? passingMarks;
  final double? passPercentage;
  final String? instructionsHtml;
  final Map<String, dynamic> settings;
  final double totalMarks;
  final List<BandCount> balance;
  final PracticeExposure? exposure;

  /// Why this paper cannot be published yet, straight from the same
  /// ExamBuilderService::publishBlocker the web builder uses — so the app never
  /// offers a publish the server will refuse.
  final String? publishBlocker;

  final List<BuilderSection> sections;
  final List<ExamSchedule> schedules;

  const ExamBuilderState({
    required this.id,
    required this.title,
    required this.type,
    required this.publishState,
    required this.durationMinutes,
    required this.settings,
    required this.totalMarks,
    required this.balance,
    required this.sections,
    required this.schedules,
    this.subjectId,
    this.passingMarks,
    this.passPercentage,
    this.instructionsHtml,
    this.exposure,
    this.publishBlocker,
  });

  bool get isPublished => publishState == 'published';
  bool get canPublish => publishBlocker == null;
  int get questionCount => sections.fold(0, (sum, s) => sum + s.questions.length);

  factory ExamBuilderState.fromJson(Map<String, dynamic> json) => ExamBuilderState(
        id: _i(json['id']),
        title: _s(json['title'], 'Untitled'),
        type: _s(json['type'], ExamKind.exam),
        publishState: _s(json['publish_state'], 'draft'),
        subjectId: (json['subject_id'] as num?)?.toInt(),
        durationMinutes: _i(json['duration_minutes']),
        passingMarks: (json['passing_marks'] as num?)?.toInt(),
        passPercentage: (json['pass_percentage'] as num?)?.toDouble(),
        instructionsHtml: json['instructions_html']?.toString(),
        settings: _map(json['settings']),
        totalMarks: _d(json['total_marks']),
        balance: _maps(json['balance']).map(BandCount.fromJson).toList(),
        exposure: json['exposure'] == null
            ? null
            : PracticeExposure.fromJson(_map(json['exposure'])),
        publishBlocker: json['publish_blocker']?.toString(),
        sections: _maps(json['sections']).map(BuilderSection.fromJson).toList(),
        schedules: _maps(json['schedules']).map(ExamSchedule.fromJson).toList(),
      );
}

/// One difficulty band's share of the paper. Labels come from the school's
/// DifficultyRegistry — never assume easy/medium/hard.
class BandCount {
  final String key;
  final String label;
  final int count;
  final double percent;

  const BandCount({
    required this.key,
    required this.label,
    required this.count,
    required this.percent,
  });

  factory BandCount.fromJson(Map<String, dynamic> json) => BandCount(
        key: _s(json['key'], ''),
        label: _s(json['label'], ''),
        count: _i(json['count']),
        percent: _d(json['percent']),
      );
}

/// Advisory: questions on this paper the cohort has already drilled in practice,
/// where the solution was shown. Never blocks anything.
class PracticeExposure {
  final int exposed;
  final int total;
  final int threshold;

  const PracticeExposure({
    required this.exposed,
    required this.total,
    required this.threshold,
  });

  bool get hasWarning => exposed > 0;

  factory PracticeExposure.fromJson(Map<String, dynamic> json) => PracticeExposure(
        exposed: _i(json['exposed']),
        total: _i(json['total']),
        threshold: _i(json['threshold']),
      );
}

class BuilderSection {
  final int id;
  final String name;
  final int position;
  final String? instructionsHtml;
  final int? durationMinutes;
  final double? marksPerQuestion;
  final double? negativeMarks;
  final double? cutoffPercentage;
  final bool isOptional;
  final int? pickCount;
  final Map<String, dynamic>? blueprint;

  /// Bands the blueprint asks for but the section does not have enough of.
  final List<Map<String, dynamic>> shortfall;

  final List<BuilderQuestion> questions;

  const BuilderSection({
    required this.id,
    required this.name,
    required this.position,
    required this.isOptional,
    required this.questions,
    required this.shortfall,
    this.instructionsHtml,
    this.durationMinutes,
    this.marksPerQuestion,
    this.negativeMarks,
    this.cutoffPercentage,
    this.pickCount,
    this.blueprint,
  });

  factory BuilderSection.fromJson(Map<String, dynamic> json) => BuilderSection(
        id: _i(json['id']),
        name: _s(json['name'], 'Section'),
        position: _i(json['position']),
        instructionsHtml: json['instructions_html']?.toString(),
        durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
        marksPerQuestion: (json['marks_per_question'] as num?)?.toDouble(),
        negativeMarks: (json['negative_marks'] as num?)?.toDouble(),
        cutoffPercentage: (json['cutoff_percentage'] as num?)?.toDouble(),
        isOptional: json['is_optional'] == true,
        pickCount: (json['pick_count'] as num?)?.toInt(),
        blueprint: json['difficulty_blueprint'] == null
            ? null
            : _map(json['difficulty_blueprint']),
        shortfall: _maps(json['shortfall']),
        questions: _maps(json['questions']).map(BuilderQuestion.fromJson).toList(),
      );
}

class BuilderQuestion {
  /// The pivot row id — what a detach targets, NOT the bank question id.
  final int rowId;
  final int questionId;
  final String question;
  final String type;
  final String difficulty;
  final double marks;
  final int position;

  const BuilderQuestion({
    required this.rowId,
    required this.questionId,
    required this.question,
    required this.type,
    required this.difficulty,
    required this.marks,
    required this.position,
  });

  factory BuilderQuestion.fromJson(Map<String, dynamic> json) => BuilderQuestion(
        rowId: _i(json['row_id']),
        questionId: _i(json['question_id']),
        question: _s(json['question'], ''),
        type: _s(json['type'], ''),
        difficulty: _s(json['difficulty'], ''),
        marks: _d(json['marks']),
        position: _i(json['position']),
      );
}

/// A bank question offered by the picker.
class PoolQuestion {
  final int id;
  final String question;
  final String type;
  final String difficulty;
  final double marks;

  const PoolQuestion({
    required this.id,
    required this.question,
    required this.type,
    required this.difficulty,
    required this.marks,
  });

  factory PoolQuestion.fromJson(Map<String, dynamic> json) => PoolQuestion(
        id: _i(json['id']),
        question: _s(json['question'], ''),
        type: _s(json['type'], ''),
        difficulty: _s(json['difficulty'], ''),
        marks: _d(json['marks']),
      );
}

/// A {id, name} pair from the options endpoint.
class ExamOption {
  final int id;
  final String name;
  final int? parentId;

  const ExamOption({required this.id, required this.name, this.parentId});

  factory ExamOption.fromJson(Map<String, dynamic> json) => ExamOption(
        id: _i(json['id']),
        name: _s(json['name'], ''),
        parentId: (json['school_class_id'] as num?)?.toInt(),
      );
}

/// A {key, label} pair — question types and difficulty bands.
class ExamKeyOption {
  final String key;
  final String label;

  const ExamKeyOption({required this.key, required this.label});

  factory ExamKeyOption.fromJson(Map<String, dynamic> json) => ExamKeyOption(
        key: _s(json['key'], ''),
        label: _s(json['label'], ''),
      );
}

/// Everything the authoring forms need to describe themselves.
class BuilderOptions {
  final List<ExamOption> classes;
  final List<ExamOption> sections;
  final List<ExamOption> subjects;
  final List<ExamOption> topics;
  final List<ExamKeyOption> types;
  final List<ExamKeyOption> bands;

  const BuilderOptions({
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.topics,
    required this.types,
    required this.bands,
  });

  List<ExamOption> sectionsFor(int? classId) =>
      classId == null ? const [] : sections.where((s) => s.parentId == classId).toList();

  factory BuilderOptions.fromJson(Map<String, dynamic> json) => BuilderOptions(
        classes: _maps(json['classes']).map(ExamOption.fromJson).toList(),
        sections: _maps(json['sections']).map(ExamOption.fromJson).toList(),
        subjects: _maps(json['subjects']).map(ExamOption.fromJson).toList(),
        topics: _maps(json['topics']).map(ExamOption.fromJson).toList(),
        types: _maps(json['types']).map(ExamKeyOption.fromJson).toList(),
        bands: _maps(json['bands']).map(ExamKeyOption.fromJson).toList(),
      );
}

/// A recently-run paper with how the cohort did on it.
class RecentPaper {
  final int examId;
  final String title;
  final String type;
  final String subject;
  final bool isPractice;
  final int students;

  /// Null when nobody has sat it yet — which is not the same as zero.
  final int? avgPercentage;

  /// Accuracy on the hardest band: the figure that separates "they did fine"
  /// from "they collapsed on the hard half". Band label comes from the school's
  /// registry.
  final String? hardBand;
  final int? hardAccuracy;

  const RecentPaper({
    required this.examId,
    required this.title,
    required this.type,
    required this.subject,
    required this.isPractice,
    required this.students,
    this.avgPercentage,
    this.hardBand,
    this.hardAccuracy,
  });

  factory RecentPaper.fromJson(Map<String, dynamic> json) => RecentPaper(
        examId: _i(json['exam_id']),
        title: _s(json['title'], 'Untitled'),
        type: _s(json['type'], ExamKind.exam),
        subject: _s(json['subject']),
        isPractice: json['is_practice'] == true,
        students: _i(json['students']),
        avgPercentage: (json['avg_percentage'] as num?)?.toInt(),
        hardBand: json['hard_band']?.toString(),
        hardAccuracy: (json['hard_accuracy'] as num?)?.toInt(),
      );
}

/// The module dashboard, teacher-scoped.
class ExamDashboard {
  final Map<String, dynamic> papers;
  final Map<String, dynamic> liveNow;
  final Map<String, dynamic> pendingReview;
  final Map<String, dynamic> questionBank;
  final List<Map<String, dynamic>> lowTurnout;
  final List<RecentPaper> recentPapers;
  final Map<String, dynamic> practice;

  /// True when these figures cover only the classes this teacher is allotted.
  final bool scoped;

  const ExamDashboard({
    required this.papers,
    required this.liveNow,
    required this.pendingReview,
    required this.questionBank,
    required this.lowTurnout,
    required this.recentPapers,
    required this.practice,
    required this.scoped,
  });

  int get published => _i(papers['published']);
  int get drafts => _i(papers['draft']);
  int get closingSoon => _i(papers['closing_soon']);

  factory ExamDashboard.fromJson(Map<String, dynamic> json) => ExamDashboard(
        papers: _map(json['papers']),
        liveNow: _map(json['live_now']),
        pendingReview: _map(json['pending_review']),
        questionBank: _map(json['question_bank']),
        lowTurnout: _maps(json['low_turnout']),
        recentPapers: _maps(json['recent_papers']).map(RecentPaper.fromJson).toList(),
        practice: _map(json['practice']),
        scoped: json['scoped'] == true,
      );
}
