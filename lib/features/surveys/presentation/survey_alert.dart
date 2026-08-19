import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_colors.dart';
import '../data/survey_models.dart';
import 'survey_providers.dart';

/// Invisible widget that, on app open, fetches the active "important" survey
/// (force_popup) the staff member has not answered and shows it as a launch-time
/// dialog — "Take Now" / "Later". The nudge has no "Don't Show Again": it
/// re-appears next launch until the survey is answered (or closes).
///
/// Drop one instance into the dashboard Stack (alongside the UpdateGate).
class SurveyAlertGate extends ConsumerStatefulWidget {
  const SurveyAlertGate({super.key});

  @override
  ConsumerState<SurveyAlertGate> createState() => _SurveyAlertGateState();
}

class _SurveyAlertGateState extends ConsumerState<SurveyAlertGate> {
  /// Tokens already handled in this app run, so returning to the dashboard
  /// doesn't re-open the dialog. Cleared on a fresh launch, so the nudge returns.
  static final Set<String> _handledThisRun = {};

  @override
  Widget build(BuildContext context) {
    ref.watch(surveyPopupProvider).whenData(_maybeShow);
    return const SizedBox.shrink();
  }

  void _maybeShow(SurveyInvitationSummary? item) {
    if (item == null || _handledThisRun.contains(item.token)) return;
    _handledThisRun.add(item.token);
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SurveyAlertDialog(item: item),
      );
    });
  }
}

/// The "important survey" modal: title, description, question count, with a
/// prominent "Take Survey Now" alongside "Later".
class SurveyAlertDialog extends ConsumerWidget {
  final SurveyInvitationSummary item;
  const SurveyAlertDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final survey = item.survey;
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.iconBgSurvey,
                  child: Icon(Icons.poll_outlined, color: AppColors.iconFgSurvey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'A survey needs your response',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              survey.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), height: 1.25),
            ),
            if (survey.description != null && survey.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(survey.description!,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.help_outline_rounded, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(
                  '${survey.questionCount} question${survey.questionCount == 1 ? '' : 's'}'
                  '${survey.isAnonymous ? ' · Anonymous' : ''}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final changed = await context.push<bool>('/dashboard/surveys/${item.token}');
                      if (changed == true) {
                        ref.invalidate(mySurveysProvider);
                        ref.invalidate(surveyPopupProvider);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Take Survey Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
