// lib/features/dashboard/domain/calendar_event.dart
import 'package:flutter/material.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final Color color;
  final String type;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.color,
    required this.type,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    Color colorFromHex(String hexColor) {
      hexColor = hexColor.replaceAll("#", "");
      return Color(int.parse("FF$hexColor", radix: 16));
    }

    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
      color: colorFromHex(json['color']),
      type: json['type'],
    );
  }
}