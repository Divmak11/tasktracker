import '../../../data/models/user_model.dart';

/// Centralized permission utility class for role-based access control.
/// 
/// Usage:
/// ```dart
/// if (PermissionUtils.canCreateTeam(authProvider.userRole)) {
///   // Show create team option
/// }
/// ```
class PermissionUtils {
  /// Check if user can create tasks.
  /// All authenticated users can create tasks.
  static bool canCreateTask(UserRole? role) {
    return role != null;
  }

  /// Check if user can create teams.
  /// Only Super Admin can create teams.
  static bool canCreateTeam(UserRole? role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user can approve user access requests.
  /// Only Super Admin can approve users.
  static bool canApproveUsers(UserRole? role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user can manage all users (view, edit roles, delete).
  /// Only Super Admin can manage users.
  static bool canManageUsers(UserRole? role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user can promote a Team Admin.
  /// Only Super Admin can promote Team Admins.
  static bool canPromoteTeamAdmin(UserRole? role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user can reopen completed tasks.
  /// Only Super Admin can reopen tasks.
  static bool canReopenTask(UserRole? role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user has admin privileges (Super Admin or Team Admin).
  static bool isAdmin(UserRole? role) {
    return role == UserRole.superAdmin || role == UserRole.teamAdmin;
  }

  /// Check if user is a Super Admin.
  static bool isSuperAdmin(UserRole? role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user is a Team Admin.
  static bool isTeamAdmin(UserRole? role) {
    return role == UserRole.teamAdmin;
  }

  /// Check if user is a regular Member.
  static bool isMember(UserRole? role) {
    return role == UserRole.member;
  }
}
