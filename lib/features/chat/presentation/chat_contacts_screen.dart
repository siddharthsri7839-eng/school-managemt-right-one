import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../data/chat_models.dart';
import 'chat_providers.dart';

/// New-chat picker: my sections → students, with a choice of messaging the
/// student or their parent (whichever accounts exist and are enabled).
class ChatContactsScreen extends ConsumerWidget {
  const ChatContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(chatContactsProvider);
    final config = ref.watch(chatConfigProvider).valueOrNull;

    return MainScaffold(
      title: 'New Conversation',
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(chatContactsProvider.future),
        child: contactsState.when(
          loading: () => SkeletonLoaders.listTile(),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 100),
              Center(child: Text(err.toString())),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(chatContactsProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (sections) {
            if (sections.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No sections are assigned to you yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: sections
                  .map((section) => _SectionTile(
                        section: section,
                        studentChatOn: config?.teacherStudentEnabled ?? true,
                        parentChatOn: config?.teacherParentEnabled ?? true,
                      ))
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _SectionTile extends ConsumerWidget {
  final ChatSectionContacts section;
  final bool studentChatOn;
  final bool parentChatOn;

  const _SectionTile({
    required this.section,
    required this.studentChatOn,
    required this.parentChatOn,
  });

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ChatStudentContact student,
    String type,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final threadId = await ref
          .read(chatRepositoryProvider)
          .openThread(type: type, studentId: student.studentId);
      final title = type == 'teacher_parent'
          ? 'Parent of ${student.name}'
          : student.name;
      router.push(
        '/dashboard/chat/thread/$threadId',
        extra: {'title': title, 'frozen': false},
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _pickTarget(BuildContext context, WidgetRef ref, ChatStudentContact s) {
    final canStudent = studentChatOn && s.canStudentChat;
    final canParent = parentChatOn && s.canParentChat;

    if (canStudent && !canParent) {
      _open(context, ref, s, 'teacher_student');
      return;
    }
    if (canParent && !canStudent) {
      _open(context, ref, s, 'teacher_parent');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text('Message ${s.name}'),
              enabled: canStudent,
              subtitle: canStudent ? null : const Text('No student login account'),
              onTap: canStudent
                  ? () {
                      Navigator.pop(sheetContext);
                      _open(context, ref, s, 'teacher_student');
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom),
              title: Text('Message parent of ${s.name}'),
              enabled: canParent,
              subtitle: canParent ? null : const Text('No parent account linked'),
              onTap: canParent
                  ? () {
                      Navigator.pop(sheetContext);
                      _open(context, ref, s, 'teacher_parent');
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      leading: const Icon(Icons.class_outlined),
      title: Text(
        section.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${section.students.length} students'),
      children: section.students.map((s) {
        final reachable = (studentChatOn && s.canStudentChat) ||
            (parentChatOn && s.canParentChat);
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?'),
          ),
          title: Text(s.name),
          subtitle: reachable
              ? null
              : const Text('No app account for student or parent',
                  style: TextStyle(fontSize: 11)),
          trailing: reachable ? const Icon(Icons.chevron_right) : null,
          enabled: reachable,
          onTap: reachable ? () => _pickTarget(context, ref, s) : null,
        );
      }).toList(),
    );
  }
}
