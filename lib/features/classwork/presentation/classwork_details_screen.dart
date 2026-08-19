import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/core/branding/branding_providers.dart';
import 'package:school_erp_staff_app/shared/presentation/document_viewer_screen.dart';
import 'classwork_providers.dart';

class ClassworkDetailsScreen extends ConsumerWidget {
  final Map<String, dynamic> classwork;

  const ClassworkDetailsScreen({super.key, required this.classwork});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(classworkRepositoryProvider).deleteClasswork(classwork['id']);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry Deleted.')));
          context.pop(); // Go back to list
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = DateTime.parse(classwork['date']);
    final type = classwork['type'].toString().toLowerCase();
    
    Color typeColor = Colors.green;
    IconData typeIcon = Icons.assignment;
    if (type == 'logbook') {
      typeColor = Colors.orange;
      typeIcon = Icons.book;
    } else if (type == 'notes') {
      typeColor = Colors.purple;
      typeIcon = Icons.note_alt;
    }

    final attachments = classwork['attachments'] as List<dynamic>? ?? [];
    final storageBaseUrl = ref.watch(apiClientProvider).storageBaseUrl;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Details'),
        elevation: 0,
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final fullClasswork = ref.watch(classworkDetailsProvider(classwork['id'])).valueOrNull ?? classwork;
              return IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: 'Edit Entry',
                onPressed: () async {
                  await context.push('/dashboard/classwork/edit', extra: fullClasswork);
                  ref.invalidate(classworkListProvider);
                  ref.invalidate(classworkDetailsProvider(classwork['id']));
                  if (context.mounted) {
                    context.pop(); // Pop details to return to the refreshed list
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            tooltip: 'Delete Entry',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: typeColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          classwork['type'].toString().toUpperCase(),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    classwork['topic'],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildMetaRow(Icons.calendar_today, 'Date', DateFormat('EEEE, dd MMM yyyy').format(date)),
                  const SizedBox(height: 12),
                  _buildMetaRow(Icons.class_outlined, ref.watch(terminologyProvider).classLabel, '${classwork['school_class']['name']} - ${classwork['section']['name']}'),
                  if (classwork['subject'] != null) ...[
                    const SizedBox(height: 12),
                    _buildMetaRow(Icons.subject, ref.watch(terminologyProvider).subjectLabel, classwork['subject']['name']),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Content Card (Fetch Details)
            ref.watch(classworkDetailsProvider(classwork['id'])).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading details: $e')),
              data: (fullClasswork) {
                final content = fullClasswork['content'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Content & Notes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: content == null || content.toString().trim().isEmpty
                          ? const Text('No content provided.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                          : HtmlWidget(
                              content,
                              textStyle: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                            ),
                    ),
                  ],
                );
              },
            ),
            
            // Attachments
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Attachments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              ...attachments.map((path) {
                // The API now resolves attachments to absolute URLs; resolveMedia
                // still guards any legacy relative value.
                final url =
                    ApiClient.resolveMedia(storageBaseUrl, path.toString()) ??
                        path.toString();
                // Clean filename from the URL PATH (drop any ?signature=… query).
                final filename =
                    (Uri.tryParse(url)?.pathSegments.isNotEmpty ?? false)
                        ? Uri.parse(url).pathSegments.last
                        : path.toString().split('/').last;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.shade100),
                  ),
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.attach_file, color: Colors.blue),
                    title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.open_in_new, color: Colors.blue),
                    onTap: () {
                      // Open inside the app (same inbuilt viewer as homework),
                      // instead of bouncing out to an external browser.
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(
                            title: filename,
                            url: url,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label:', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
