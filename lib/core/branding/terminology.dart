import 'package:flutter/foundation.dart';

/// One governed noun in both grammatical numbers ("Year" / "Years").
@immutable
class Term {
  final String singular;
  final String plural;
  const Term(this.singular, this.plural);
}

/// The school's academic wording (Class / Section / Subject), from the
/// `terms` slice of the `/branding` payload (schema v2) — the app half of
/// backend docs/academic-terminology-plan.md Phase 4. An international school
/// can read Year / Form, a CBC school Grade / Stream, off the same API.
///
/// Parsed defensively like [Branding]: any missing/invalid field degrades to
/// the canonical English the app shipped with, and a payload with the feature
/// flag off (or an old schema-v1 payload with no `terms` at all) collapses to
/// [Terminology.fallback] entirely. Wording can never break a screen.
@immutable
class Terminology {
  final bool enabled;
  final Term classTerm;
  final Term sectionTerm;
  final Term subjectTerm;

  const Terminology({
    required this.enabled,
    required this.classTerm,
    required this.sectionTerm,
    required this.subjectTerm,
  });

  /// Canonical English — the exact strings previously hardcoded in the UI.
  /// Mirror of the server's TerminologyService::hardDefaults().
  const Terminology.fallback()
      : enabled = false,
        classTerm = const Term('Class', 'Classes'),
        sectionTerm = const Term('Section', 'Sections'),
        subjectTerm = const Term('Subject', 'Subjects');

  /// Parse the FULL branding payload (not just its `terms` key). Never throws.
  factory Terminology.fromJson(Map<String, dynamic> json) {
    // Flag off, old payload, or junk → exactly what the app shipped with.
    if (json['terminology_enabled'] != true) return const Terminology.fallback();

    final terms = (json['terms'] is Map)
        ? Map<String, dynamic>.from(json['terms'] as Map)
        : const <String, dynamic>{};

    const fb = Terminology.fallback();
    return Terminology(
      enabled: true,
      classTerm: _term(terms['class'], fb.classTerm),
      sectionTerm: _term(terms['section'], fb.sectionTerm),
      subjectTerm: _term(terms['subject'], fb.subjectTerm),
    );
  }

  // Convenience getters. Named *Label deliberately: `className`/`sectionName`
  // already mean "the name of THIS student's class/section" all over the app.
  String get classLabel => classTerm.singular;
  String get classesLabel => classTerm.plural;
  String get sectionLabel => sectionTerm.singular;
  String get sectionsLabel => sectionTerm.plural;
  String get subjectLabel => subjectTerm.singular;
  String get subjectsLabel => subjectTerm.plural;

  // ── Defensive parsers ──────────────────────────────────────────────────────

  static Term _term(dynamic v, Term fb) {
    if (v is! Map) return fb;
    final singular = _word(v['singular']) ?? fb.singular;
    // The server always sends a plural; if it's somehow missing, naive +s is
    // right for every curated preset word and beats showing the wrong noun.
    final plural = _word(v['plural']) ??
        (singular == fb.singular ? fb.plural : '${singular}s');
    return Term(singular, plural);
  }

  static String? _word(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    if (t.isEmpty) return null;
    return t.length > 30 ? t.substring(0, 30) : t;
  }
}
