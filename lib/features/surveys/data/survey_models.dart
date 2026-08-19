// Plain data models for the Surveys & Feedback feature.
//
// Mirrors the JSON shaped by Api\V1\Staff\SurveyController. Kept as simple
// classes with `fromJson` factories, per the app's feature conventions.

class SurveySummary {
  final int id;
  final String title;
  final String? description;
  final String kind; // survey | poll | feedback_form
  final bool isAnonymous;
  final bool isOpen;
  final int questionCount;
  final DateTime? closesAt;

  const SurveySummary({
    required this.id,
    required this.title,
    this.description,
    required this.kind,
    required this.isAnonymous,
    required this.isOpen,
    required this.questionCount,
    this.closesAt,
  });

  factory SurveySummary.fromJson(Map<String, dynamic> json) {
    return SurveySummary(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      kind: (json['kind'] ?? 'survey') as String,
      isAnonymous: json['is_anonymous'] == true,
      isOpen: json['is_open'] == true,
      questionCount: (json['question_count'] ?? 0) as int,
      closesAt: json['closes_at'] != null
          ? DateTime.tryParse(json['closes_at'] as String)
          : null,
    );
  }

  /// A friendly label for the survey kind chip.
  String get kindLabel {
    switch (kind) {
      case 'poll':
        return 'Poll';
      case 'feedback_form':
        return 'Feedback';
      default:
        return 'Survey';
    }
  }
}

/// One item in the "My Surveys" inbox — an invitation + its survey summary.
class SurveyInvitationSummary {
  final String token;
  final bool responded;
  final DateTime? respondedAt;
  final SurveySummary survey;

  const SurveyInvitationSummary({
    required this.token,
    required this.responded,
    this.respondedAt,
    required this.survey,
  });

  factory SurveyInvitationSummary.fromJson(Map<String, dynamic> json) {
    return SurveyInvitationSummary(
      token: json['token'] as String,
      responded: json['responded'] == true,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      survey: SurveySummary.fromJson(
        Map<String, dynamic>.from(json['survey'] as Map),
      ),
    );
  }

  /// Still awaiting an answer (unanswered and the survey is open).
  bool get isPending => !responded && survey.isOpen;
}

class SurveyChoice {
  final String id;
  final String label;

  const SurveyChoice({required this.id, required this.label});

  factory SurveyChoice.fromJson(Map<String, dynamic> json) {
    return SurveyChoice(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

class SurveyScale {
  final int min;
  final int max;
  final String? minLabel;
  final String? maxLabel;

  const SurveyScale({
    required this.min,
    required this.max,
    this.minLabel,
    this.maxLabel,
  });

  factory SurveyScale.fromJson(Map<String, dynamic> json) {
    return SurveyScale(
      min: (json['min'] ?? 1) as int,
      max: (json['max'] ?? 5) as int,
      minLabel: json['min_label'] as String?,
      maxLabel: json['max_label'] as String?,
    );
  }

  /// NPS-style 0–10 questions get a slightly different treatment.
  bool get isNps => min == 0 && max == 10;
}

class SurveyQuestion {
  final int id;
  final String type;
  final String prompt;
  final String? helpText;
  final bool isRequired;
  final SurveyScale? scale;
  final List<SurveyChoice> choices;

  const SurveyQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.helpText,
    required this.isRequired,
    this.scale,
    this.choices = const [],
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      id: json['id'] as int,
      type: (json['type'] ?? '') as String,
      prompt: (json['prompt'] ?? '') as String,
      helpText: json['help_text'] as String?,
      isRequired: json['is_required'] == true,
      scale: json['scale'] != null
          ? SurveyScale.fromJson(Map<String, dynamic>.from(json['scale'] as Map))
          : null,
      choices: (json['choices'] as List?)
              ?.map((c) => SurveyChoice.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          const [],
    );
  }

  bool get isSectionBreak => type == 'section_break';
  bool get isAnswerable => !isSectionBreak;
}

/// Full survey payload for the respond screen.
class SurveyDetail {
  final String token;
  final bool alreadyResponded;
  final bool allowResubmit;
  final bool isOpen;
  final SurveySummary survey;
  final List<SurveyQuestion> questions;

  const SurveyDetail({
    required this.token,
    required this.alreadyResponded,
    required this.allowResubmit,
    required this.isOpen,
    required this.survey,
    required this.questions,
  });

  factory SurveyDetail.fromJson(Map<String, dynamic> json) {
    final s = Map<String, dynamic>.from(json['survey'] as Map);
    return SurveyDetail(
      token: json['token'] as String,
      alreadyResponded: json['already_responded'] == true,
      allowResubmit: json['allow_resubmit'] == true,
      isOpen: json['is_open'] == true,
      survey: SurveySummary(
        id: s['id'] as int,
        title: (s['title'] ?? '') as String,
        description: s['description'] as String?,
        kind: (s['kind'] ?? 'survey') as String,
        isAnonymous: s['is_anonymous'] == true,
        isOpen: json['is_open'] == true,
        questionCount: (json['questions'] as List?)?.length ?? 0,
        closesAt: null,
      ),
      questions: (json['questions'] as List? ?? const [])
          .map((q) => SurveyQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList(),
    );
  }

  /// Answering can proceed only when open and not already locked.
  bool get canRespond => isOpen && (!alreadyResponded || allowResubmit);
}
