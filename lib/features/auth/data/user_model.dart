import 'package:flutter/foundation.dart';

@immutable
class User {
  final int id;
  final String name;
  final String email;
  final String userType;
  final String? role;
  final List<String> permissions;
  final String? profilePhotoUrl;
  final String? schoolName;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.userType,
    this.role,
    this.permissions = const [],
    this.profilePhotoUrl,
    this.schoolName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      userType: json['user_type'],
      role: json['role'],
      permissions: List<String>.from(json['permissions'] ?? []),
      profilePhotoUrl: json['profile_photo_url'],
      schoolName: json['school_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'user_type': userType,
      'role': role,
      'permissions': permissions,
      'profile_photo_url': profilePhotoUrl,
      'school_name': schoolName,
    };
  }
}