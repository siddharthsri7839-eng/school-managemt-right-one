import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/features/auth/data/user_model.dart';
import 'package:school_erp_staff_app/features/auth/presentation/auth_controller.dart';
import 'app_permission.dart';
import 'app_role.dart';

/// Immutable snapshot of the current user's authorization state.
///
/// This is the **single source of truth** for role/permission checks
/// throughout the entire app. Every screen, widget, drawer, and router
/// should use this instead of raw `user?.role == 'school_admin'` checks.
@immutable
class PermissionState {
  final AppRole role;
  final Set<AppPermission> _granted;

  const PermissionState({
    required this.role,
    required Set<AppPermission> granted,
  }) : _granted = granted;

  /// Empty state for unauthenticated users.
  const PermissionState.empty()
      : role = AppRole.other,
        _granted = const {};

  // ── Permission checks ──────────────────────────────────────

  /// Check if the user has a specific permission.
  bool can(AppPermission permission) => _granted.contains(permission);

  /// Check if the user has ANY of the given permissions.
  bool canAny(Set<AppPermission> permissions) =>
      permissions.any((p) => _granted.contains(p));

  /// Check if the user has ALL of the given permissions.
  bool canAll(Set<AppPermission> permissions) =>
      permissions.every((p) => _granted.contains(p));

  // ── Role checks ────────────────────────────────────────────

  /// Check if the user has a specific role.
  bool hasRole(AppRole r) => role == r;

  /// Whether the user holds an "academic" role (admin or teacher).
  /// These roles can access student data, attendance, marks, etc.
  bool get isAcademic => role.isAcademic;

  /// Whether the user is a school administrator.
  bool get isAdmin => role == AppRole.schoolAdmin;

  /// Whether the user is a teacher.
  bool get isTeacher => role == AppRole.teacher;

  // ── Display helpers ────────────────────────────────────────

  /// Human-readable role name for UI display.
  String get displayRoleName => role.displayName;

  /// Full set of granted permissions (for debugging / logging).
  Set<AppPermission> get grantedPermissions => Set.unmodifiable(_granted);
}

/// Global provider that derives the permission state from the auth state.
///
/// Usage:
/// ```dart
/// final perms = ref.watch(permissionProvider);
/// if (perms.can(AppPermission.noticeCreate)) { ... }
/// if (perms.isAdmin) { ... }
/// ```
final permissionProvider = Provider<PermissionState>((ref) {
  final asyncUser = ref.watch(authControllerProvider);
  final user = asyncUser.valueOrNull;

  if (user == null) {
    return const PermissionState.empty();
  }

  return _buildPermissionState(user);
});

/// Build the permission state from the user data.
///
/// Strategy:
/// 1. If the backend sent a non-empty `permissions` array, parse those
///    into the enum set. This is the "proper" path.
/// 2. If the backend sent an empty/missing `permissions` array (legacy),
///    fall back to the role's `defaultPermissions`.
PermissionState _buildPermissionState(User user) {
  final role = AppRole.fromString(user.role);

  Set<AppPermission> granted;

  if (user.permissions.isNotEmpty) {
    // Backend sent granular permissions — use them directly.
    granted = AppPermission.fromBackendKeys(user.permissions);
    // Also include the role's defaults as a safety net so basic
    // features always work even if the backend admin forgot to
    // assign a specific permission.
    granted = granted.union(role.defaultPermissions);
  } else {
    // Legacy backend — fall back to role-based defaults.
    granted = role.defaultPermissions;
  }

  debugPrint(
      '🔐 [Permissions] Role: ${role.displayName}, '
      'Granted: ${granted.length} permissions '
      '(backend sent ${user.permissions.length})');

  return PermissionState(role: role, granted: granted);
}
