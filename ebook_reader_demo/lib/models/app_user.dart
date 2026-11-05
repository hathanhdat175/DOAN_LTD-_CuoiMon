import 'enums.dart';
import 'json.dart';

/// Người dùng hệ thống (bảng Users).
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.locked = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      name: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: userRoleFromCode(json['role'] as String? ?? 'Reader'),
      joinedAt: parseDate(json['createdAt']),
      locked: json['isLocked'] == true,
    );
  }

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime joinedAt;
  bool locked;
}
