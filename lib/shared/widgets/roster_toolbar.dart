// lib/shared/widgets/roster_toolbar.dart
//
// Reusable roster header: a live count summary + search field + sort menu.
// Presentational only — the parent owns the query/sort state and does the
// actual filtering/sorting. Used by Take Attendance and Marks Entry so both
// screens share one search/sort/summary experience.

import 'package:flutter/material.dart';

/// A single labelled count shown in the summary strip (e.g. "Present · 24").
class RosterCount {
  final String label;
  final int count;
  final Color color;
  const RosterCount(this.label, this.count, this.color);
}

/// One option in the sort menu.
class RosterSortOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  const RosterSortOption({required this.value, required this.label, this.icon});
}

class RosterToolbar<T> extends StatelessWidget {
  final List<RosterCount> counts;

  final String query;
  final ValueChanged<String> onQueryChanged;
  final String searchHint;

  final List<RosterSortOption<T>> sortOptions;
  final T sortValue;
  final ValueChanged<T> onSortChanged;

  const RosterToolbar({
    super.key,
    required this.counts,
    required this.query,
    required this.onQueryChanged,
    required this.sortOptions,
    required this.sortValue,
    required this.onSortChanged,
    this.searchHint = 'Search by name or roll…',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (counts.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  for (final c in counts) ...[
                    _CountChip(count: c),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(child: _SearchField(
                  query: query,
                  hint: searchHint,
                  onChanged: onQueryChanged,
                )),
                const SizedBox(width: 8),
                _SortButton<T>(
                  options: sortOptions,
                  value: sortValue,
                  onChanged: onSortChanged,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final RosterCount count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: count.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: count.color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${count.count}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: count.color),
          ),
          const SizedBox(width: 5),
          Text(
            count.label,
            style: TextStyle(
                fontSize: 12, color: count.color.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.query, required this.hint, required this.onChanged});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _SortButton<T> extends StatelessWidget {
  final List<RosterSortOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  const _SortButton(
      {required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<T>(
      tooltip: 'Sort',
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<T>(
            value: o.value,
            child: Row(
              children: [
                Icon(o.icon ?? Icons.sort,
                    size: 18,
                    color: o.value == value ? theme.colorScheme.primary : null),
                const SizedBox(width: 10),
                Text(o.label,
                    style: TextStyle(
                        fontWeight: o.value == value
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color:
                            o.value == value ? theme.colorScheme.primary : null)),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 18),
            SizedBox(width: 6),
            Text('Sort', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
