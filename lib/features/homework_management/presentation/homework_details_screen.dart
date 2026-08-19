import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ✅ ADD THIS IMPORT STATEMENT to link to your core API services
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/branding/branding_providers.dart';
import 'package:school_erp_staff_app/shared/presentation/document_viewer_screen.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

import 'homework_providers.dart';

class HomeworkDetailsScreen extends ConsumerStatefulWidget {
  final int homeworkId;
  const HomeworkDetailsScreen({super.key, required this.homeworkId});

  @override
  ConsumerState<HomeworkDetailsScreen> createState() =>
      _HomeworkDetailsScreenState();
}

class _HomeworkDetailsScreenState extends ConsumerState<HomeworkDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All'; // All, Submitted, Not Submitted, Evaluated

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _hasSubmission(Map student) =>
      (student['submissions'] as List?)?.isNotEmpty ?? false;

  bool _isEvaluated(Map student) {
    final subs = student['submissions'] as List?;
    if (subs == null || subs.isEmpty) return false;
    return subs.first['marks'] != null;
  }

  @override
  Widget build(BuildContext context) {
    final homeworkId = widget.homeworkId;
    final detailsState = ref.watch(homeworkDetailsProvider(homeworkId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework Submissions'),
      ),
      body: detailsState.when(
        loading: () => SkeletonLoaders.detailPage(),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          final homework = data['homework'];
          final students =
              (data['students'] as List).cast<Map<String, dynamic>>();

          final total = students.length;
          final submitted = students.where(_hasSubmission).length;
          final evaluated = students.where(_isEvaluated).length;
          final notSubmitted = total - submitted;

          final query = _searchController.text.trim().toLowerCase();
          final filtered = students.where((s) {
            bool statusMatch = true;
            switch (_statusFilter) {
              case 'Submitted':
                statusMatch = _hasSubmission(s);
                break;
              case 'Not Submitted':
                statusMatch = !_hasSubmission(s);
                break;
              case 'Evaluated':
                statusMatch = _isEvaluated(s);
                break;
            }
            if (!statusMatch) return false;
            if (query.isEmpty) return true;
            final name =
                "${s['first_name'] ?? ''} ${s['last_name'] ?? ''}".toLowerCase();
            final roll = "${s['roll_no'] ?? ''}".toLowerCase();
            return name.contains(query) || roll.contains(query);
          }).toList();

          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(homeworkDetailsProvider(homeworkId).future),
            child: ListView.builder(
              itemCount: filtered.length + 1, // +1 for the header block
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      _HomeworkHeader(homework: homework),
                      _buildSummary(submitted, notSubmitted, evaluated, total),
                      _buildSearchAndFilter(),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No students match your filter.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        ),
                    ],
                  );
                }
                final student = filtered[index - 1];
                final submission = (student['submissions'] as List).isNotEmpty
                    ? student['submissions'][0]
                    : null;

                return _SubmissionTile(
                  student: student,
                  submission: submission,
                  homeworkId: homeworkId,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(int submitted, int notSubmitted, int evaluated, int total) {
    Widget stat(String label, int value, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text('$value',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          stat('Submitted', submitted, Colors.green.shade600,
              Icons.check_circle_outline),
          stat('Pending', notSubmitted, Colors.orange.shade700,
              Icons.hourglass_empty),
          stat('Graded', evaluated, Colors.blue.shade600, Icons.grading),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final theme = Theme.of(context);
    const filters = ['All', 'Submitted', 'Not Submitted', 'Evaluated'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search student by name or roll no...',
              prefixIcon: Icon(Icons.search, color: theme.primaryColor, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () =>
                          setState(() => _searchController.clear()),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final selected = _statusFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = f),
                    selectedColor: theme.primaryColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: selected ? theme.primaryColor : Colors.grey.shade700,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HomeworkHeader extends ConsumerWidget {
  final Map<String, dynamic> homework;
  const _HomeworkHeader({required this.homework});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = homework['title'] ?? 'No Title';
    final subject = homework['subject']?['name'] ?? 'N/A';
    final className = homework['school_class']?['name'] ?? 'N/A';
    final sectionName = homework['section']?['name'] ?? 'N/A';
    final dueDateStr = homework['due_date'] != null
        ? DateFormat('dd MMM, yyyy').format(DateTime.parse(homework['due_date']))
        : 'N/A';
    final description = homework['description'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${ref.watch(terminologyProvider).subjectLabel}: $subject'),
          Text('${ref.watch(terminologyProvider).classLabel}: $className - $sectionName'),
          Text('Due Date: $dueDateStr'),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description),
          ],
          const Divider(height: 32),
          Text('Student Submissions',
              style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _SubmissionTile extends ConsumerWidget {
  final Map<String, dynamic> student;
  final Map<String, dynamic>? submission;
  final int homeworkId;

  const _SubmissionTile({
    required this.student,
    this.submission,
    required this.homeworkId,
  });

  void _showEvaluationDialog(BuildContext context, WidgetRef ref) {
    final marksController = TextEditingController(text: submission?['marks']?.toString() ?? '');
    final remarksController = TextEditingController(text: submission?['remarks'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Evaluate Submission'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: marksController,
                    decoration: const InputDecoration(labelText: 'Marks (Optional)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: remarksController,
                    decoration: const InputDecoration(labelText: 'Remarks (Optional)'),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);
                          try {
                            await ref.read(homeworkEvaluationControllerProvider).submitEvaluation(
                                  submissionId: submission!['id'],
                                  marks: marksController.text.trim(),
                                  remarks: remarksController.text.trim(),
                                );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Evaluation saved successfully')),
                              );
                              ref.refresh(homeworkDetailsProvider(homeworkId).future);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _viewSubmission(BuildContext context, ApiClient apiClient) {
    final filePath = submission?['file_path'];
    if (filePath == null) return;

    // The API returns an absolute signed URL for the submission; resolveMedia
    // passes absolute URLs through untouched (and only prefixes relatives).
    final String? fullUrl =
        ApiClient.resolveMedia(apiClient.storageBaseUrl, filePath.toString());
    if (fullUrl == null) return;

    final studentName =
        "${student['first_name'] ?? ''} ${student['last_name'] ?? ''}".trim();

    // Open the submission INSIDE the app (same concept as the web viewer)
    // instead of bouncing out to an external browser.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: studentName.isNotEmpty ? studentName : 'Submission',
          url: fullUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiClient = ref.watch(apiClientProvider);
    final theme = Theme.of(context);
    final bool isEvaluated = submission?['marks'] != null;
    final bool hasFile = submission?['file_path'] != null;

    final String label;
    final Color fg;
    final Color bg;
    if (submission == null) {
      label = 'Not Submitted';
      fg = Colors.grey.shade700;
      bg = Colors.grey.shade200;
    } else if (isEvaluated) {
      label = 'Marks: ${submission!['marks']}';
      fg = Colors.white;
      bg = Colors.green.shade600;
    } else {
      label = 'Submitted';
      fg = Colors.white;
      bg = Colors.blue.shade600;
    }

    final studentName =
        "${student['first_name'] ?? ''} ${student['last_name'] ?? ''}".trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: submission != null
            ? () => _showEvaluationDialog(context, ref)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              // Name + roll — takes all remaining width so the trailing
              // status/actions never get squeezed.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName.isNotEmpty ? studentName : 'Unknown Student',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Roll No: ${student['roll_no'] ?? 'N/A'}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge (compact — no bulky Chip padding).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                      color: fg, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              // View button — only when there's a file.
              if (hasFile) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  onPressed: () => _viewSubmission(context, apiClient),
                  tooltip: 'View submission',
                  color: theme.primaryColor,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: const EdgeInsets.all(8),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.primaryColor.withOpacity(0.10),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}