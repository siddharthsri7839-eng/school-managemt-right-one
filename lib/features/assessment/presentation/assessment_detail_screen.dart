import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/secure_pdf_viewer_screen.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/branding/branding_providers.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment_models.dart';
import 'assessment_providers.dart';
import 'assessment_widgets.dart';

class AssessmentDetailScreen extends ConsumerWidget {
  final int assessmentId;
  const AssessmentDetailScreen({super.key, required this.assessmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentDetailProvider(assessmentId));

    return MainScaffold(
      title: 'Assessment',
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          if (err is ApiException && err.message == 'module_disabled') {
            return const AssessmentModuleDisabled();
          }
          return ApiErrorWidget(error: err, onRetry: () => ref.invalidate(assessmentDetailProvider(assessmentId)));
        },
        data: (a) => RefreshIndicator(
          onRefresh: () async => ref.refresh(assessmentDetailProvider(assessmentId).future),
          child: _body(context, ref, a),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, AssessmentDetail a) {
    final typeColor = assessmentTypeColor(a.type);
    final classLine = [a.className, a.section].where((e) => e != null && e.isNotEmpty).join(' / ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (a.typeLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: typeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(a.typeLabel!.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor)),
                    ),
                  const Spacer(),
                  if (a.canUpdate)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit',
                      onPressed: () async {
                        final changed = await context.push<bool>('/dashboard/assessment/${a.id}/edit', extra: a);
                        if (changed == true) ref.invalidate(assessmentDetailProvider(assessmentId));
                      },
                    ),
                  if (a.canDelete)
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: a.hasMarks ? Colors.grey : Colors.red),
                      tooltip: a.hasMarks ? 'Has marks — cannot delete' : 'Delete',
                      onPressed: a.hasMarks ? null : () => _confirmDelete(context, ref, a),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(a.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _infoRow(Icons.menu_book_outlined, ref.watch(terminologyProvider).subjectLabel, a.subject ?? '—'),
              _infoRow(Icons.class_outlined, ref.watch(terminologyProvider).classLabel, classLine.isEmpty ? '—' : classLine),
              _infoRow(Icons.grade_outlined, 'Total marks',
                  '${_num(a.totalMarks)}${a.passingMarks != null ? '  (pass ${_num(a.passingMarks)})' : ''}'),
              if (a.frequency != null) _infoRow(Icons.repeat, 'Frequency', a.frequency!),
              if (a.creatorName != null) _infoRow(Icons.person_outline, 'Created by', a.creatorName!),
              if (a.instructions != null && a.instructions!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(a.instructions!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Sittings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (a.occurrences.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No sittings yet.', style: TextStyle(color: Colors.grey)))
        else
          ...a.occurrences.map((o) => _sittingTile(context, ref, a, o)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sittingTile(BuildContext context, WidgetRef ref, AssessmentDetail a, OccurrenceRow o) {
    final statusColor = occurrenceStatusColor(o.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: () async {
          await context.push('/dashboard/assessment/occurrence/${o.id}');
          ref.invalidate(assessmentDetailProvider(assessmentId));
        },
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.12),
          child: Icon(o.isLocked ? Icons.lock_outline : Icons.edit_outlined, color: statusColor, size: 20),
        ),
        title: Text(o.scheduledDate ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${o.enteredCount} marks entered', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text((o.statusLabel ?? '').toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              tooltip: 'Marksheet PDF',
              onPressed: () {
                final url = ref.read(assessmentRepositoryProvider).exportPath('marksheet', {'occurrence_id': o.id});
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SecurePdfViewerScreen(title: 'Marksheet', pdfUrl: url),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AssessmentDetail a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete assessment?'),
        content: Text('“${a.title}” and its sittings will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await ref.read(assessmentRepositoryProvider).delete(a.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Delete failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _num(double? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
}
