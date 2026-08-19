// lib/features/online_exam/presentation/mark_attempt_screen.dart
//
// Marking one student's written answers.
//
// One answer per card: the question, what the student wrote, the teacher's own
// model answer (safe here — it never goes near a student), and a marks field
// capped at what the question is worth on THIS paper.
//
// The server clamps the award anyway, so an over-typed number comes back
// corrected rather than rejected. The cap in the UI is a courtesy, not the
// guard — the guard is ManualReviewService::award.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../data/online_exam_repository.dart';
import '../domain/online_exam_models.dart';
import 'online_exam_providers.dart';

class MarkAttemptScreen extends ConsumerWidget {
  final int attemptId;
  const MarkAttemptScreen({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attemptReviewProvider(attemptId));

    return MainScaffold(
      title: 'Mark answers',
      body: state.when(
        loading: () => SkeletonLoaders.cardList(),
        error: (err, _) => ListView(
          children: [
            const SizedBox(height: 100),
            ApiErrorWidget(
              error: err,
              onRetry: () => ref.invalidate(attemptReviewProvider(attemptId)),
            ),
          ],
        ),
        data: (review) {
          if (review.answers.isEmpty) {
            return _AllDone(student: review.student, score: review.score, max: review.maxScore);
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Header(review: review),
              const SizedBox(height: 12),
              ...review.answers.map(
                (answer) => _AnswerCard(
                  attemptId: attemptId,
                  answer: answer,
                  total: review.answers.length,
                  index: review.answers.indexOf(answer) + 1,
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AttemptReview review;
  const _Header({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.student,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (review.exam != null)
                  Text(
                    review.exam!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            '${review.answers.length} to mark',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD98A00),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  final String student;
  final double score;
  final double max;

  const _AllDone({required this.student, required this.score, required this.max});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF1E9E6A)),
            const SizedBox(height: 12),
            const Text(
              'All marked',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '$student scored ${score.toStringAsFixed(score % 1 == 0 ? 0 : 2)} '
              'of ${max.toStringAsFixed(max % 1 == 0 ? 0 : 2)}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Back to the queue'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One answer, with its own marks field and Save.
class _AnswerCard extends ConsumerStatefulWidget {
  final int attemptId;
  final PendingAnswer answer;
  final int index;
  final int total;

  const _AnswerCard({
    required this.attemptId,
    required this.answer,
    required this.index,
    required this.total,
  });

  @override
  ConsumerState<_AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends ConsumerState<_AnswerCard> {
  final _marks = TextEditingController();
  final _comment = TextEditingController();
  bool _busy = false;
  bool _showRubric = false;

  @override
  void dispose() {
    _marks.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_marks.text.trim());

    if (value == null) {
      _say('Enter a mark first.');
      return;
    }

    setState(() => _busy = true);

    try {
      final outcome = await ref.read(onlineExamRepositoryProvider).award(
            widget.attemptId,
            answerId: widget.answer.answerId,
            marks: value,
            comment: _comment.text.trim(),
          );

      if (!mounted) return;

      _say(outcome.message);

      // The queue count changed and this attempt has one fewer pending answer;
      // both must refetch or the teacher marks a graded answer twice.
      ref.invalidate(markingQueueProvider);
      ref.invalidate(attemptReviewProvider(widget.attemptId));
      ref.invalidate(examDashboardProvider);
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } catch (_) {
      if (mounted) _say('Could not save that mark. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answer;
    final maxLabel = answer.maxMarks.toStringAsFixed(answer.maxMarks % 1 == 0 ? 0 : 2);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Q${widget.index} of ${widget.total}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    answer.typeLabel,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  'out of $maxLabel',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _plain(answer.question),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),

            // The student's answer, visually separated — this is the thing
            // being judged and it should not blend into the question.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2F6FED).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2F6FED).withValues(alpha: 0.15)),
              ),
              child: Text(
                answer.response.trim().isEmpty
                    // Blank is a real outcome and needs marking too, usually 0.
                    ? 'Left blank'
                    : _plain(answer.response),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontStyle: answer.response.trim().isEmpty ? FontStyle.italic : null,
                  color: answer.response.trim().isEmpty ? Colors.grey.shade600 : null,
                ),
              ),
            ),

            if (answer.rubric != null && answer.rubric!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _showRubric = !_showRubric),
                child: Row(
                  children: [
                    Icon(
                      _showRubric ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showRubric ? 'Hide model answer' : 'Show model answer',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              if (_showRubric)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E9E6A).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _plain(answer.rubric!),
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _marks,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Marks',
                      hintText: '0–$maxLabel',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _comment,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // A blank answer is nearly always zero; save the typing.
                TextButton(
                  onPressed: _busy ? null : () => _marks.text = '0',
                  child: const Text('0'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _marks.text = maxLabel,
                  child: Text('Full ($maxLabel)'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save mark'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Question and solution bodies are authored as HTML in the web editor. The
  /// marking view wants the words, not the markup.
  String _plain(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}
