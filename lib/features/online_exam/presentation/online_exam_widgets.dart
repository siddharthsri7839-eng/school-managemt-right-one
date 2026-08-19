// lib/features/online_exam/presentation/online_exam_widgets.dart
//
// Shared pieces for the teacher's online-exam screens.
//
// The kind colours are TAXONOMY, not decoration: exam / quiz / practice mean
// three different things to a student, and the parent app and web portal use
// the same three hues. Changing one here without the others is how a student
// and their teacher end up looking at differently-coloured versions of the same
// paper.

import 'package:flutter/material.dart';
import '../domain/online_exam_models.dart';

const kExamColor = Color(0xFF2F6FED);
const kQuizColor = Color(0xFF7A4FE0);
const kPracticeColor = Color(0xFF1E9E6A);

Color examKindColor(String type) => switch (type) {
      ExamKind.quiz => kQuizColor,
      ExamKind.practice => kPracticeColor,
      _ => kExamColor,
    };

/// A TabBar that is legible on a white page.
///
/// The app's global `tabBarTheme` is written for a TabBar sitting INSIDE the
/// coloured AppBar: `labelColor` is white and `unselectedLabelColor` is 66%
/// white. Dropped onto a page background those are white-on-white — the labels
/// vanish. Every other on-page TabBar in this app overrides the colours inline
/// for the same reason; this wraps it so the feature does it once and cannot
/// forget on the next screen.
class ExamTabBar extends StatelessWidget {
  final List<String> tabs;
  final bool scrollable;

  const ExamTabBar({super.key, required this.tabs, this.scrollable = false});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: TabBar(
        isScrollable: scrollable,
        tabAlignment: scrollable ? TabAlignment.start : null,
        labelColor: primary,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: primary,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12.5),
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}

/// The module-off state, matching Assessment's.
class OnlineExamModuleDisabled extends StatelessWidget {
  const OnlineExamModuleDisabled({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Online Exams is switched off',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask your school administrator to enable the module.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Exam / Quiz / Practice Set.
class ExamKindBadge extends StatelessWidget {
  final String type;
  const ExamKindBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = examKindColor(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ExamKind.label(type).toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

/// Draft / window state, in words a teacher acts on.
class ExamStateChip extends StatelessWidget {
  final ExamPaper paper;
  const ExamStateChip({super.key, required this.paper});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    if (paper.isDraft) {
      // Draft outranks the window: an unpublished paper's dates mean nothing
      // because no student can see it.
      color = Colors.orange.shade700;
      label = 'Draft';
    } else if (paper.isPractice) {
      color = kPracticeColor;
      label = 'Always open';
    } else {
      switch (paper.windowState) {
        case 'upcoming':
          color = Colors.blueGrey;
          label = 'Upcoming';
        case 'completed':
          color = Colors.grey.shade600;
          label = 'Closed';
        default:
          color = const Color(0xFF1E9E6A);
          label = 'Open now';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// A headline number with its own tint, as on the web dashboard.
class ExamStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  const ExamStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The difficulty balance of a paper, as a single stacked bar.
///
/// Band labels come from the school's own registry — never hard-code
/// easy/medium/hard, a school may run five bands with its own names.
class DifficultyBalanceBar extends StatelessWidget {
  final List<BandCount> bands;
  const DifficultyBalanceBar({super.key, required this.bands});

  static const _palette = [
    Color(0xFF2F9E68),
    Color(0xFF57A773),
    Color(0xFFE0A800),
    Color(0xFFE8833A),
    Color(0xFFD9534F),
    Color(0xFF868E96),
  ];

  @override
  Widget build(BuildContext context) {
    final present = bands.where((b) => b.count > 0).toList();

    if (present.isEmpty) {
      return Text(
        'Add questions to see the difficulty mix.',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (var i = 0; i < present.length; i++)
                  Expanded(
                    flex: present[i].count,
                    child: Container(color: _colorFor(present[i], i)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < present.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colorFor(present[i], i),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${present[i].label} · ${present[i].count}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Color _colorFor(BandCount band, int index) {
    // Position in the full band list, so a colour means the same band whether
    // or not the paper happens to contain the ones before it.
    final ordinal = bands.indexWhere((b) => b.key == band.key);
    return _palette[(ordinal < 0 ? index : ordinal) % _palette.length];
  }
}

/// An empty state that says which of the two empties it is.
class ExamEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const ExamEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
