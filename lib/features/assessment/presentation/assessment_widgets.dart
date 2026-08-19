import 'package:flutter/material.dart';
import '../domain/assessment_models.dart';

/// Shown when the assessment module is turned off for the school.
class AssessmentModuleDisabled extends StatelessWidget {
  const AssessmentModuleDisabled({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.fact_check_outlined, size: 76, color: Colors.red.shade400),
            ),
            const SizedBox(height: 28),
            const Text('Assessment Module Disabled',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            const Text(
              'The Continuous Assessment module is currently disabled for your school. Please contact your school administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact KPI card used on the dashboard and report summaries.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: color),
              ),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                    textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Colour for an assessment type chip.
Color assessmentTypeColor(String? type) {
  switch (type) {
    case 'quiz':
      return Colors.blue;
    case 'test':
      return Colors.deepPurple;
    case 'oral':
      return Colors.teal;
    case 'practical':
      return Colors.orange;
    case 'assignment':
      return Colors.green;
    default:
      return Colors.blueGrey;
  }
}

/// Colour for a sitting status badge.
Color occurrenceStatusColor(String? status) {
  switch (status) {
    case 'published':
      return Colors.green;
    case 'grading':
      return Colors.orange;
    case 'open':
      return Colors.blue;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

/// List tile for one assessment (dashboard recents + browse list).
class AssessmentListTile extends StatelessWidget {
  final AssessmentSummary assessment;
  final VoidCallback onTap;

  const AssessmentListTile({super.key, required this.assessment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final typeColor = assessmentTypeColor(a.type);
    final classLine = [a.className, a.section].where((e) => e != null && e.isNotEmpty).join(' / ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (a.typeLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: typeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(a.typeLabel!.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor)),
                ),
              if (a.subject != null) Text(a.subject!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              if (classLine.isNotEmpty) Text('• $classLine', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${a.sittings}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('sittings', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
