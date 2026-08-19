import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/features/attendance/presentation/attendance_providers.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';
import 'package:school_erp_staff_app/core/branding/branding_providers.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'notice_providers.dart';

class CreateNoticeScreen extends ConsumerStatefulWidget {
  const CreateNoticeScreen({super.key});

  @override
  ConsumerState<CreateNoticeScreen> createState() => _CreateNoticeScreenState();
}

class _CreateNoticeScreenState extends ConsumerState<CreateNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final quill.QuillController _quillController = quill.QuillController.basic();

  String _recipientType = 'class'; // Default to class to be safe for teachers
  dynamic _selectedClass;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _submitNotice() async {
    if (_formKey.currentState!.validate()) {
      // Validate content manually since it's no longer a TextFormField
      if (_quillController.document.isEmpty()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the notice content.')),
        );
        return;
      }

      // Additional validation for class selection
      if (_recipientType == 'class' && _selectedClass == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a ${ref.read(terminologyProvider).classLabel.toLowerCase()}.')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Convert the Quill Delta to HTML
        final deltaJson = _quillController.document.toDelta().toJson();
        // The converter expects a List<Map<String, dynamic>> but toJson might return List<dynamic>
        final List<Map<String, dynamic>> deltaOps = List<Map<String, dynamic>>.from(deltaJson);
        final converter = QuillDeltaToHtmlConverter(deltaOps);
        final htmlContent = converter.convert();

        await ref.read(createNoticeControllerProvider).submitNotice(
              title: _titleController.text,
              content: htmlContent,
              publishedAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
              recipientType: _recipientType,
              noticableId: _selectedClass?['id'],
            );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notice published successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We need the list of classes for the dropdown
    final classesState = ref.watch(classesProvider);
    final perms = ref.watch(permissionProvider);
    
    // Initialize default selection based on role
    if (!_initialized) {
      if (perms.isAdmin || !perms.isTeacher) {
        _recipientType = 'all';
      } else {
        _recipientType = 'class';
      }
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Notice'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (value) => (value?.isEmpty ?? true) ? 'Please enter a title.' : null,
              ),
              const SizedBox(height: 16),
              
              // Native Quill Editor
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    quill.QuillSimpleToolbar(
                      controller: _quillController,
                      config: const quill.QuillSimpleToolbarConfig(
                        showFontFamily: false,
                        showFontSize: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showInlineCode: false,
                        showCodeBlock: false,
                        showSearchButton: false,
                        showIndent: false,
                        showDirection: false,
                        showColorButton: false,
                        showBackgroundColorButton: false,
                        showClipboardCopy: false,
                        showClipboardCut: false,
                        showClipboardPaste: false,
                        showListCheck: false,
                        showHeaderStyle: false,
                        showStrikeThrough: false,
                        showClearFormat: false,
                        multiRowsDisplay: false,
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(8.0),
                      child: quill.QuillEditor.basic(
                        controller: _quillController,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _recipientType,
                items: [
                  if (perms.isAdmin || !perms.isTeacher) ...[
                    const DropdownMenuItem(value: 'all', child: Text('All Users')),
                    const DropdownMenuItem(value: 'parents', child: Text('All Parents')),
                  ],
                  DropdownMenuItem(value: 'class', child: Text('A Specific ${ref.watch(terminologyProvider).classLabel}')),
                ],
                onChanged: (value) {
                  setState(() {
                    _recipientType = value!;
                    _selectedClass = null; // Reset class selection
                  });
                },
                decoration: const InputDecoration(labelText: 'Publish To', border: OutlineInputBorder()),
              ),
              if (_recipientType == 'class') ...[
                const SizedBox(height: 16),
                classesState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Could not load classes: $err'),
                  data: (classes) => DropdownButtonFormField<dynamic>(
                    value: _selectedClass,
                    items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c['name']))).toList(),
                    onChanged: (value) => setState(() => _selectedClass = value),
                    decoration: InputDecoration(labelText: 'Select ${ref.watch(terminologyProvider).classLabel}', border: const OutlineInputBorder()),
                    validator: (value) => (_recipientType == 'class' && value == null) ? 'Please select a ${ref.read(terminologyProvider).classLabel.toLowerCase()}.' : null,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _isLoading ? null : _submitNotice,
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                    : const Text('Publish Notice'),
              )
            ],
          ),
        ),
      ),
    );
  }
}