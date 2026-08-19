import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import '../../../core/branding/branding_providers.dart';
import '../domain/marks_models.dart';
import 'marks_controller.dart';
import 'marks_entry_screen.dart';

class MarksSelectionScreen extends ConsumerStatefulWidget {
  const MarksSelectionScreen({super.key});

  @override
  ConsumerState<MarksSelectionScreen> createState() => _MarksSelectionScreenState();
}

// lib/features/exam_marks/presentation/marks_selection_screen.dart

class _MarksSelectionScreenState extends ConsumerState<MarksSelectionScreen> {
  Exam? _selectedExam;
  SchoolClass? _selectedClass;
  Section? _selectedSection;

  List<SchoolClass> _classes = [];
  List<Section> _sections = [];
  bool _isLoadingClasses = false;
  bool _isLoadingSections = false;

  // ✅ This method is now called when an exam is selected
  void _onExamChanged(Exam? newExam) async {
    if (newExam == null) return;
    setState(() {
      _selectedExam = newExam;
      _selectedClass = null;
      _selectedSection = null;
      _classes = [];
      _sections = [];
      _isLoadingClasses = true; // Show a loading indicator
    });

    // Call the API to get the valid classes for the selected exam
    final classes = await ref.read(marksSelectionProvider.notifier).getClassesForExam(newExam.id);

    setState(() {
      _classes = classes;
      _isLoadingClasses = false;
    });
  }

  // This method is now called when a class is selected
  void _onClassChanged(SchoolClass? newClass) async {
    if (newClass == null) return;
    setState(() {
      _selectedClass = newClass;
      _selectedSection = null;
      _sections = [];
      _isLoadingSections = true;
    });
    final sections = await ref.read(marksSelectionProvider.notifier).getSections(newClass.id);
    setState(() {
      _sections = sections;
      _isLoadingSections = false;
    });
  }
  
  void _fetchStudents() {
    if (_selectedExam != null && _selectedClass != null && _selectedSection != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => 
        MarksEntryScreen(
          examId: _selectedExam!.id, 
          classId: _selectedClass!.id, 
          sectionId: _selectedSection!.id,
          header: '${_selectedExam!.name} - ${_selectedClass!.name} (${_selectedSection!.name})',
        )
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(marksSelectionProvider);
    return MainScaffold(
      // ✅ THE FIX: Wrap the entire body in a SafeArea widget.
      body: SafeArea(
        // Add a minimum padding to ensure the button doesn't touch the edges.
        minimum: const EdgeInsets.all(16.0),
        child: options.when(
          loading: () => SkeletonLoaders.dashboard(),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (data) {
            final List<Exam> exams = data['exams'] ?? []; // Add null check for safety
            
            // Add a check for teachers with no assigned classes
            if (_selectedExam != null && !_isLoadingClasses && _classes.isEmpty) {
              return Center(
                child: Text(
                  'No ${ref.watch(terminologyProvider).classesLabel.toLowerCase()} with this exam setup have been assigned to your account. Please contact the administrator.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Column(
              children: [
                DropdownButtonFormField<Exam>(
                  value: _selectedExam,
                  items: exams.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                  onChanged: _onExamChanged,
                  decoration: const InputDecoration(labelText: 'Select Exam', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SchoolClass>(
                  value: _selectedClass,
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: _onClassChanged,
                  decoration: InputDecoration(
                    labelText: 'Select ${ref.watch(terminologyProvider).classLabel}',
                    border: const OutlineInputBorder(),
                    suffixIcon: _isLoadingClasses ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2.0)) : null,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Section>(
                  value: _selectedSection,
                  items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                  onChanged: (v) => setState(() => _selectedSection = v),
                  decoration: InputDecoration(
                    labelText: 'Select ${ref.watch(terminologyProvider).sectionLabel}',
                    border: const OutlineInputBorder(),
                    suffixIcon: _isLoadingSections ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2.0)) : null,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: (_selectedExam != null && _selectedClass != null && _selectedSection != null) ? _fetchStudents : null,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Fetch Students & Enter Marks'),
                )
              ],
            );
          }
        ),
      ),
    );
  }

}