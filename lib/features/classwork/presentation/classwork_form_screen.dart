import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:school_erp_staff_app/features/homework_management/presentation/homework_providers.dart';
import 'package:school_erp_staff_app/core/branding/branding_providers.dart';
import 'classwork_providers.dart';

class ClassworkFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const ClassworkFormScreen({super.key, this.initialData});

  @override
  ConsumerState<ClassworkFormScreen> createState() => _ClassworkFormScreenState();
}

class _ClassworkFormScreenState extends ConsumerState<ClassworkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _selectedType = 'Classwork';
  final List<String> _types = ['Classwork', 'Logbook', 'Notes'];

  dynamic _selectedClass;
  dynamic _selectedSection;
  dynamic _selectedSubject;
  DateTime? _selectedDate;
  File? _selectedFile;
  bool _isLoading = false;
  bool _classSectionInitialized = false;
  bool _subjectInitialized = false;

  final _topicController = TextEditingController();
  final quill.QuillController _quillController = quill.QuillController.basic();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final cw = widget.initialData!;
      // For type, topic, content, date, we can populate directly.
      // For class/section/subject, the user will have to re-select if editing,
      // or we can try to pre-select them if we manage the data correctly.
      // For simplicity in this demo, if editing, they must re-select class hierarchy.
      _selectedType = _types.firstWhere((t) => t.toLowerCase() == cw['type'].toString().toLowerCase(), orElse: () => 'Classwork');
      _topicController.text = cw['topic'] ?? '';
      
      // Convert HTML content back to Quill Delta for editing (preserves formatting)
      final String htmlContent = cw['content'] ?? '';
      if (htmlContent.trim().isNotEmpty) {
        try {
          final delta = HtmlToDelta().convert(htmlContent);
          _quillController.document = quill.Document.fromDelta(delta);
        } catch (_) {
          // Fallback: strip HTML tags and load as plain text
          final plainText = htmlContent
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&nbsp;', ' ')
              .trim();
          if (plainText.isNotEmpty) {
            _quillController.document.insert(0, plainText);
          }
        }
      }
      _selectedDate = DateTime.tryParse(cw['date'].toString());
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  /// Strips nested 'Exception:' prefixes from error messages for clean display.
  String _cleanErrorMessage(Object error) {
    String msg = error.toString();
    // Remove all leading 'Exception:' wrappers
    while (msg.startsWith('Exception: ')) {
      msg = msg.substring('Exception: '.length);
    }
    return msg;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedDate != null && (_selectedType == 'Logbook' || _selectedSubject != null)) {
      if (_quillController.document.isEmpty()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter content.')));
        return;
      }
      
      setState(() => _isLoading = true);
      try {
        final deltaJson = _quillController.document.toDelta().toJson();
        final List<Map<String, dynamic>> deltaOps = deltaJson
            .whereType<Map<String, dynamic>>()
            .toList();
        if (deltaOps.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not process content.')));
          return;
        }
        final converter = QuillDeltaToHtmlConverter(deltaOps);
        final htmlContent = converter.convert();

        final data = {
          'school_class_id': _selectedClass['id'],
          'section_id': _selectedSection['id'],
          'type': _selectedType.toLowerCase(),
          'topic': _topicController.text,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          'content': htmlContent,
        };

        // Subject is optional for logbook entries (class-wide, not subject-specific)
        if (_selectedSubject != null) {
          data['subject_id'] = _selectedSubject['id'];
        }

        final repo = ref.read(classworkRepositoryProvider);
        if (widget.initialData != null) {
          // Update
          await repo.updateClasswork(widget.initialData!['id'], data, file: _selectedFile);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry Updated!')));
        } else {
          // Create
          await repo.createClasswork(data, file: _selectedFile);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry Created!')));
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanErrorMessage(e))));
      } finally {
        if(mounted) setState(() => _isLoading = false);
      }
    } else if (_selectedSubject == null && _selectedType != 'Logbook') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a ${ref.read(terminologyProvider).classLabel.toLowerCase()}, ${ref.read(terminologyProvider).sectionLabel.toLowerCase()}, and ${ref.read(terminologyProvider).subjectLabel.toLowerCase()}.')));
    } else if (_selectedClass == null || _selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a ${ref.read(terminologyProvider).classLabel.toLowerCase()} and ${ref.read(terminologyProvider).sectionLabel.toLowerCase()}.')));
    }
  }

  Future<void> _delete() async {
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
      setState(() => _isLoading = true);
      try {
        await ref.read(classworkRepositoryProvider).deleteClasswork(widget.initialData!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry Deleted.')));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanErrorMessage(e))));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesState = ref.watch(homeworkClassesProvider);
    final isEditing = widget.initialData != null;

    if (isEditing && !_classSectionInitialized) {
      classesState.whenData((classes) {
        final cw = widget.initialData!;
        try {
          // Homework structure uses cw['school_class_id'] or cw['school_class']['id'] depending on API
          final classId = cw['school_class'] != null ? cw['school_class']['id'] : cw['school_class_id'];
          final sectionId = cw['section'] != null ? cw['section']['id'] : cw['section_id'];
          
          final c = classes.firstWhere((x) => x['id'] == classId);
          final s = (c['sections'] as List).firstWhere((x) => x['id'] == sectionId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedClass = c;
                _selectedSection = s;
                _classSectionInitialized = true;
              });
            }
          });
        } catch (_) {}
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Entry' : 'Create Entry'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _delete,
              tooltip: 'Delete Entry',
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() {
                  _selectedType = val!;
                  // Logbook entries don't need a subject — clear any stale selection
                  if (_selectedType == 'Logbook') {
                    _selectedSubject = null;
                  }
                }),
                decoration: const InputDecoration(labelText: 'Entry Type', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // Topic / Title
              TextFormField(
                controller: _topicController,
                decoration: const InputDecoration(labelText: 'Topic / Title', border: OutlineInputBorder()),
                validator: (val) => (val?.isEmpty ?? true) ? 'Please enter a topic' : null,
              ),
              const SizedBox(height: 16),

              // Date Picker
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
                leading: const Icon(Icons.calendar_today),
                title: Text(_selectedDate == null ? 'Select Date' : DateFormat('dd MMM, yyyy').format(_selectedDate!)),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),

              // Class / Section / Subject Hierarchy
              classesState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error loading classes: $e'),
                data: (classes) => Column(
                  children: [
                    DropdownButtonFormField<dynamic>(
                       value: _selectedClass,
                       items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c['name'] as String))).toList(),
                       onChanged: (val) => setState(() {
                         _selectedClass = val;
                         _selectedSection = null;
                         _selectedSubject = null;
                       }),
                       decoration: InputDecoration(labelText: ref.watch(terminologyProvider).classLabel, border: const OutlineInputBorder()),
                       validator: (val) => val == null ? 'Please select a ${ref.read(terminologyProvider).classLabel.toLowerCase()}' : null,
                    ),
                    const SizedBox(height: 16),
                    if (_selectedClass != null)
                      DropdownButtonFormField<dynamic>(
                        value: _selectedSection,
                        items: (_selectedClass['sections'] as List).map((s) => DropdownMenuItem(value: s, child: Text(s['name'] as String))).toList(),
                        onChanged: (val) => setState(() {
                           _selectedSection = val;
                           _selectedSubject = null;
                        }),
                        decoration: InputDecoration(labelText: ref.watch(terminologyProvider).sectionLabel, border: const OutlineInputBorder()),
                        validator: (val) => val == null ? 'Please select a ${ref.read(terminologyProvider).sectionLabel.toLowerCase()}' : null,
                      ),
                    const SizedBox(height: 16),
                    if (_selectedClass != null && _selectedType != 'Logbook') ...[
                      Consumer(
                        builder: (context, ref, child) {
                          final subjectsState = ref.watch(subjectsProvider(_selectedClass['id']));
                          
                          if (isEditing && !_subjectInitialized && _classSectionInitialized) {
                            subjectsState.whenData((subjects) {
                              final cw = widget.initialData!;
                              try {
                                final subjectId = cw['subject'] != null ? cw['subject']['id'] : cw['subject_id'];
                                if (subjectId != null) {
                                  final sub = subjects.firstWhere((x) => x['id'] == subjectId);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedSubject = sub;
                                        _subjectInitialized = true;
                                      });
                                    }
                                  });
                                } else {
                                  _subjectInitialized = true;
                                }
                              } catch (_) {
                                _subjectInitialized = true;
                              }
                            });
                          }

                          return subjectsState.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (e, s) => Text('Error loading subjects: $e'),
                            data: (subjects) {
                              if (subjects.isEmpty) {
                                return TextFormField(
                                  decoration: InputDecoration(
                                    labelText: ref.watch(terminologyProvider).subjectLabel,
                                    border: const OutlineInputBorder(),
                                    hintText:
                                        'No ${ref.watch(terminologyProvider).subjectsLabel.toLowerCase()} assigned to this ${ref.watch(terminologyProvider).classLabel.toLowerCase()}',
                                  ),
                                  enabled: false,
                                );
                              }
                              return DropdownButtonFormField<dynamic>(
                                value: _selectedSubject,
                                items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s['name'] as String))).toList(),
                                onChanged: (val) => setState(() => _selectedSubject = val),
                                decoration: InputDecoration(labelText: ref.watch(terminologyProvider).subjectLabel, border: const OutlineInputBorder()),
                                validator: (val) => val == null ? 'Please select a ${ref.read(terminologyProvider).subjectLabel.toLowerCase()}' : null,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ]
                  ],
                ),
              ),

              // Content / Notes (Rich Text Editor)
              const Text('Content / Notes', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
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
                        showInlineCode: false,
                        showCodeBlock: false,
                        showIndent: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showAlignmentButtons: true,
                        showColorButton: true,
                        showBackgroundColorButton: true,
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(8),
                      child: quill.QuillEditor.basic(
                        controller: _quillController,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // File Attachment
               ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
                leading: const Icon(Icons.attach_file),
                title: Text(_selectedFile == null ? 'Attach File (Optional)' : _selectedFile!.path.split('/').last),
                onTap: _pickFile,
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)) 
                    : Text(isEditing ? 'Update Entry' : 'Create Entry'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
