// lib/features/dashboard/presentation/widgets/dashboard_calendar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../domain/calendar_event.dart';
import '../dashboard_providers.dart';

class DashboardCalendar extends ConsumerStatefulWidget {
  const DashboardCalendar({super.key});

  @override
  ConsumerState<DashboardCalendar> createState() => _DashboardCalendarState();
}

class _DashboardCalendarState extends ConsumerState<DashboardCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<CalendarEvent> _selectedEvents = [];
  Map<DateTime, List<CalendarEvent>> _eventsByDay = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final dateOnly = DateTime.utc(day.year, day.month, day.day);
    return _eventsByDay[dateOnly] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  void _groupEvents(List<CalendarEvent> events) {
    _eventsByDay = {}; // Clear previous events
    for (var event in events) {
      DateTime date = DateTime.utc(event.start.year, event.start.month, event.start.day);
      if (_eventsByDay[date] == null) {
        _eventsByDay[date] = [];
      }
      _eventsByDay[date]!.add(event);
    }
    // Update selected events for the initially selected day
    _selectedEvents = _getEventsForDay(_selectedDay!);
  }

  @override
  Widget build(BuildContext context) {
    final calendarEventsAsync = ref.watch(calendarEventsProvider);

    return calendarEventsAsync.when(
      loading: () => const Center(heightFactor: 5, child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading events: $err')),
      data: (events) {
        // Group events once data is available
        _groupEvents(events);

        return Card(
          margin: const EdgeInsets.all(8.0),
          elevation: 2,
          child: Column(
            children: [
              TableCalendar<CalendarEvent>(
                firstDay: DateTime.utc(2022, 1, 1),
                lastDay: DateTime.utc(2032, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: _onDaySelected,
                eventLoader: _getEventsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isNotEmpty) {
                      return Positioned(
                        right: 1,
                        bottom: 1,
                        child: _buildEventsMarker(events),
                      );
                    }
                    return null;
                  },
                ),
              ),
              const Divider(height: 1),
              // Display events for the selected day
              ..._selectedEvents.map((event) => ListTile(
                    leading: Icon(Icons.circle, color: event.color, size: 12),
                    title: Text(event.title),
                    dense: true,
                  )),
              if (_selectedEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("No events for this day."),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventsMarker(List<CalendarEvent> events) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.deepPurple, // Or a color of your choice
      ),
      width: 16.0,
      height: 16.0,
      child: Center(
        child: Text(
          '${events.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }
}