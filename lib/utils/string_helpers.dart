// lib/utils/string_helpers.dart
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    // Replace underscores with spaces and capitalize each word
    return split('_')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }
}