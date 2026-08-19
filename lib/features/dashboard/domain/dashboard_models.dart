import 'package:flutter/foundation.dart';

@immutable
class TodayScheduleItem {
  final String startTime;
  final String endTime;
  final String subject;
  final String className;
  final String sectionName;

  const TodayScheduleItem({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.className,
    required this.sectionName,
  });

  factory TodayScheduleItem.fromJson(Map<String, dynamic> json) {
    return TodayScheduleItem(
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      subject: json['subject'] ?? 'N/A',
      className: json['class_name'] ?? '',
      sectionName: json['section_name'] ?? '',
    );
  }
}


@immutable
class UpcomingEventItem {
  final String title;
  final String date;
  final String type; // 'event', 'holiday', or 'notice'

  const UpcomingEventItem({
    required this.title,
    required this.date,
    required this.type,
  });

  factory UpcomingEventItem.fromJson(Map<String, dynamic> json) {
    return UpcomingEventItem(
      title: json['title'] ?? 'No Title',
      date: json['date'] ?? '',
      type: json['type'] ?? 'event',
    );
  }
}