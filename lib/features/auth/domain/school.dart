// lib/features/auth/domain/school.dart
class School {
  final int id;
  final String name;
  final String? logoUrl;

  School({required this.id, required this.name, this.logoUrl});

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logo_url'],
    );
  }
}