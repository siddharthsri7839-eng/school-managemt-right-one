import 'package:flutter/foundation.dart';

@immutable
class Period {
  final String startTime;
  final String endTime;
  final String subject;
  final String className;
  final String sectionName;

  const Period({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.className,
    required this.sectionName,
  });

  factory Period.fromJson(Map<String, dynamic> json) {
    return Period(
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      subject: json['subject'] ?? 'N/A',
      className: json['class_name'] ?? '',
      sectionName: json['section_name'] ?? '',
    );
  }
}

// A type alias for our main data structure for easier use.
typedef TimetableData = Map<String, List<Period>>;