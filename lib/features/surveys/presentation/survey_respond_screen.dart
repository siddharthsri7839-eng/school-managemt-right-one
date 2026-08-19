import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_exception.dart';
import '../data/survey_models.dart';
import 'survey_providers.dart';

/// Renders a survey's questions and submits the answers. Every answerable
/// question type the builder supports has an input here; required questions are
/// validated client-side before the POST (the backend validates too).
class SurveyRespondScreen extends ConsumerStatefulWidget {
  final String token;
  const SurveyRespondScreen({super.key, required this.token});

  @override
  ConsumerState<SurveyRespondScreen> createState() => _SurveyRespondScreenState();
}

class _SurveyRespondScreenState extends ConsumerState<SurveyRespondScreen> {
  static const _titleColor = Color(0xFF1E293B);
  static const _labelColor = Color(0xFF64748B);

  final Map<int, dynamic> _answers = {};
  final Map<int, TextEditingController> _textControllers = {};
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int id) =>
      _textControllers.putIfAbsent(id, () => TextEditingController());

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(surveyDetailProvider(widget.token));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _centered(
          icon: Icons.error_outline,
          title: 'Could not load this survey',
          message: err is ApiException ? err.message : err.toString(),
        ),
        data: (detail) {
          if (detail.alreadyResponded && !detail.allowResubmit) {
            return _centered(
              icon: Icons.check_circle,
              iconColor: const Color(0xFF16A34A),
              title: 'Already completed',
              message: 'Thanks — you have already responded to this survey.',
            );
          }
          if (!detail.isOpen) {
            return _centered(
              icon: Icons.lock_clock,
              title: 'Survey closed',
              message: 'This survey is no longer accepting responses.',
            );
          }
          return _buildForm(detail);
        },
      ),
    );
  }

  Widget _buildForm(SurveyDetail detail) {
    final survey = detail.survey;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                survey.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _titleColor),
              ),
              if (survey.description != null && survey.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(survey.description!, style: const TextStyle(fontSize: 14, color: _labelColor)),
              ],
              if (survey.isAnonymous) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.visibility_off_outlined, size: 18, color: Color(0xFF0D9488)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This survey is anonymous — your answers are not linked to you.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF0F766E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ...detail.questions.map(_buildQuestion),
            ],
          ),
        ),
        _submitBar(detail),
      ],
    );
  }

  Widget _buildQuestion(SurveyQuestion q) {
    if (q.isSectionBreak) {
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(
          q.prompt,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _titleColor),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: q.prompt,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _titleColor),
                    children: q.isRequired
                        ? const [TextSpan(text: '  *', style: TextStyle(color: Colors.red))]
                        : null,
                  ),
                ),
              ),
            ],
          ),
          if (q.helpText != null && q.helpText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(q.helpText!, style: const TextStyle(fontSize: 12.5, color: _labelColor)),
          ],
          const SizedBox(height: 12),
          _input(q),
        ],
      ),
    );
  }

  Widget _input(SurveyQuestion q) {
    switch (q.type) {
      case 'rating':
        return _ratingInput(q);
      case 'yes_no':
        return _yesNoInput(q);
      case 'single_choice':
        return _singleChoiceInput(q);
      case 'dropdown':
        return _dropdownInput(q);
      case 'multi_choice':
        return _multiChoiceInput(q);
      case 'date':
        return _dateInput(q);
      case 'long_text':
        return _textInput(q, lines: 4);
      default: // short_text
        return _textInput(q, lines: 1);
    }
  }

  Widget _ratingInput(SurveyQuestion q) {
    final scale = q.scale ?? const SurveyScale(min: 1, max: 5);
    final selected = _answers[q.id] as int?;
    final values = [for (var i = scale.min; i <= scale.max; i++) i];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((v) {
            final isSel = selected == v;
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _answers[q.id] = v),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade100,
                  border: Border.all(
                    color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  '$v',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSel ? Colors.white : _titleColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (scale.minLabel != null || scale.maxLabel != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(scale.minLabel ?? '', style: const TextStyle(fontSize: 11.5, color: _labelColor)),
              Text(scale.maxLabel ?? '', style: const TextStyle(fontSize: 11.5, color: _labelColor)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _yesNoInput(SurveyQuestion q) {
    final val = _answers[q.id] as String?;
    Widget chip(String label, String value) {
      final isSel = val == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _answers[q.id] = value),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSel ? Colors.white : _titleColor,
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [chip('Yes', 'yes'), chip('No', 'no')]);
  }

  Widget _singleChoiceInput(SurveyQuestion q) {
    final val = _answers[q.id] as String?;
    return Column(
      children: q.choices.map((c) {
        return RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: c.id,
          groupValue: val,
          onChanged: (v) => setState(() => _answers[q.id] = v),
          title: Text(c.label, style: const TextStyle(fontSize: 14, color: _titleColor)),
        );
      }).toList(),
    );
  }

  Widget _dropdownInput(SurveyQuestion q) {
    final val = _answers[q.id] as String?;
    return DropdownButtonFormField<String>(
      value: val,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      hint: const Text('Select an option'),
      items: q.choices
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.label, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => setState(() => _answers[q.id] = v),
    );
  }

  Widget _multiChoiceInput(SurveyQuestion q) {
    final selected = (_answers[q.id] as List?)?.cast<String>() ?? <String>[];
    return Column(
      children: q.choices.map((c) {
        final isSel = selected.contains(c.id);
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: isSel,
          onChanged: (v) {
            setState(() {
              final next = List<String>.from(selected);
              if (v == true) {
                next.add(c.id);
              } else {
                next.remove(c.id);
              }
              _answers[q.id] = next;
            });
          },
          title: Text(c.label, style: const TextStyle(fontSize: 14, color: _titleColor)),
        );
      }).toList(),
    );
  }

  Widget _dateInput(SurveyQuestion q) {
    final iso = _answers[q.id] as String?;
    final display = iso != null ? DateFormat('dd MMM, yyyy').format(DateTime.parse(iso)) : 'Select a date';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: iso != null ? DateTime.parse(iso) : now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) {
          setState(() => _answers[q.id] = DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: _labelColor),
            const SizedBox(width: 10),
            Text(display, style: const TextStyle(fontSize: 14, color: _titleColor)),
          ],
        ),
      ),
    );
  }

  Widget _textInput(SurveyQuestion q, {required int lines}) {
    final controller = _controllerFor(q.id);
    return TextField(
      controller: controller,
      maxLines: lines,
      minLines: lines,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Type your answer',
      ),
      onChanged: (v) => _answers[q.id] = v.trim(),
    );
  }

  Widget _submitBar(SurveyDetail detail) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : () => _submit(detail),
            icon: _submitting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Icon(Icons.send_rounded),
            label: Text(_submitting ? 'Submitting…' : 'Submit response'),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(SurveyDetail detail) async {
    // Client-side required check (the backend enforces this too).
    for (final q in detail.questions) {
      if (!q.isAnswerable || !q.isRequired) continue;
      final a = _answers[q.id];
      final empty = a == null || (a is String && a.isEmpty) || (a is List && a.isEmpty);
      if (empty) {
        _snack('Please answer: "${q.prompt}"', error: true);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await ref.read(surveyRepositoryProvider).respond(widget.token, _answers);
      if (!mounted) return;
      _snack('Thank you — your response has been recorded.');
      Navigator.of(context).pop(true); // signal the inbox to refresh
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : 'Failed to submit. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null),
    );
  }

  Widget _centered({
    required IconData icon,
    required String title,
    required String message,
    Color? iconColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor ?? _labelColor),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _titleColor)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _labelColor)),
          ],
        ),
      ),
    );
  }
}
