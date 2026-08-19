import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/branding/branding_providers.dart';
import 'homework_providers.dart';
import 'homework_controller.dart';

class CreateHomeworkScreen extends ConsumerStatefulWidget {
  const CreateHomeworkScreen({super.key});
  @override
  ConsumerState<CreateHomeworkScreen> createState() => _CreateHomeworkScreenState();
}

class _CreateHomeworkScreenState extends ConsumerState<CreateHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  dynamic _selectedClass;
  dynamic _selectedSection;
  dynamic _selectedSubject;
  DateTime? _selectedDate;
  File? _selectedFile;
  bool _isLoading = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedDate != null && _selectedSubject != null) {
      setState(() => _isLoading = true);
      try {
        await ref.read(createHomeworkControllerProvider).create(
              classId: _selectedClass['id'],
              sectionId: _selectedSection['id'],
              subjectId: _selectedSubject['id'],
              title: _titleController.text,
              dueDate: DateFormat('yyyy-MM-dd').format(_selectedDate!),
              description: _descriptionController.text,
              filePath: _selectedFile?.path,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Homework Created!')));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if(mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesState = ref.watch(homeworkClassesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Homework')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    if (_selectedClass != null) ...[
                      Consumer(
                        builder: (context, ref, child) {
                          final subjectsState = ref.watch(subjectsProvider(_selectedClass['id']));
                          return subjectsState.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (e, s) => Text('Error loading subjects: $e'),
                            data: (subjects) {
                              if (subjects.isEmpty) {
                                // ✅ THE FIX: Removed 'const' from TextFormField
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (val) => (val?.isEmpty ?? true) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
                leading: const Icon(Icons.calendar_today),
                title: Text(_selectedDate == null ? 'Select Due Date' : DateFormat('dd MMM, yyyy').format(_selectedDate!)),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
               ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
                leading: const Icon(Icons.attach_file),
                title: Text(_selectedFile == null ? 'Attach File (Optional)' : _selectedFile!.path.split('/').last),
                onTap: _pickFile,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white),) : const Text('Create Homework'),
              )
            ],
          ),
        ),
      ),
    );
  }
}