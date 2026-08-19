// lib/features/exam_marks/domain/marks_models.dart

// Helper function to safely parse a value that might be a num, a String, or null into a double.
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

// Helper function to safely parse a value into a num, defaulting to 0.
num _parseNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

class Exam {
  final int id;
  final String name;
  Exam({required this.id, required this.name});
  factory Exam.fromJson(Map<String, dynamic> json) => Exam(id: json['id'], name: json['name']);
}

class SchoolClass {
  final int id;
  final String name;
  SchoolClass({required this.id, required this.name});
  factory SchoolClass.fromJson(Map<String, dynamic> json) => SchoolClass(id: json['id'], name: json['name']);
}

class Section {
  final int id;
  final String name;
  Section({required this.id, required this.name});
  factory Section.fromJson(Map<String, dynamic> json) => Section(id: json['id'], name: json['name']);
}

class MarkDistribution {
  final int id;
  final String subjectName;
  final String examTypeName;
  final num maxMarks;
  MarkDistribution({
    required this.id, 
    required this.subjectName, 
    required this.examTypeName, 
    required this.maxMarks
  });
  
  factory MarkDistribution.fromJson(Map<String, dynamic> json) => MarkDistribution(
        id: json['id'],
        subjectName: json['subject']?['name'] ?? 'N/A',
        examTypeName: json['exam_type']?['name'] ?? 'N/A',
        maxMarks: _parseNum(json['max_marks']),
      );
}

class StudentMark {
  final int distributionId;
  double? marksObtained;
  String attendanceStatus;
  StudentMark({
    required this.distributionId, 
    this.marksObtained, 
    required this.attendanceStatus
  });
  
  factory StudentMark.fromJson(Map<String, dynamic> json) => StudentMark(
        distributionId: json['distribution_id'],
        marksObtained: _parseDouble(json['marks_obtained']),
        attendanceStatus: json['attendance_status'],
      );
}

class StudentMarksEntry {
  final int id;
  final String fullName;
  final String rollNo; // ✅ THE FIX IS HERE (PROPERTY)
  final List<StudentMark> marks;

  StudentMarksEntry({
    required this.id, 
    required this.fullName, 
    required this.rollNo, // ✅ THE FIX IS HERE (CONSTRUCTOR)
    required this.marks
  });

  factory StudentMarksEntry.fromJson(Map<String, dynamic> json) => StudentMarksEntry(
        id: json['id'],
        fullName: json['full_name'],
        rollNo: json['roll_no']?.toString() ?? '', // ✅ THE FIX IS HERE (PARSING)
        marks: (json['marks'] as List).map((m) => StudentMark.fromJson(m)).toList(),
      );
}