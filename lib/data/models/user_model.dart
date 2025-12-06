import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  superAdmin,
  teamAdmin,
  member;

  /// Serialize to snake_case to match backend constants
  String toJson() {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.teamAdmin:
        return 'team_admin';
      case UserRole.member:
        return 'member';
    }
  }

  /// Deserialize from snake_case (backend) or camelCase (legacy app data)
  static UserRole fromJson(String value) {
    switch (value) {
      case 'super_admin':
      case 'superAdmin': // Legacy support
        return UserRole.superAdmin;
      case 'team_admin':
      case 'teamAdmin': // Legacy support
        return UserRole.teamAdmin;
      case 'member':
      default:
        return UserRole.member;
    }
  }
}

enum UserStatus {
  pending,
  active,
  revoked;

  String toJson() => name;

  static UserStatus fromJson(String value) {
    return UserStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => UserStatus.pending,
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final List<String> teamIds;
  final UserStatus status;
  final bool googleCalendarConnected;
  final String? googleAccessToken;
  final String? googleRefreshToken;
  final String? fcmToken;
  final String? avatarUrl;
  final Map<String, bool>? notificationPreferences;
  final DateTime? createdAt;
  final DateTime? lastActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.teamIds = const [],
    required this.status,
    this.googleCalendarConnected = false,
    this.googleAccessToken,
    this.googleRefreshToken,
    this.fcmToken,
    this.avatarUrl,
    this.notificationPreferences,
    this.createdAt,
    this.lastActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String id) {
    return UserModel(
      id: id,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromJson(json['role'] as String),
      teamIds: List<String>.from(json['teamIds'] ?? []),
      status: UserStatus.fromJson(json['status'] as String),
      googleCalendarConnected: json['googleCalendarConnected'] ?? false,
      googleAccessToken: json['googleAccessToken'] as String?,
      googleRefreshToken: json['googleRefreshToken'] as String?,
      fcmToken: json['fcmToken'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      notificationPreferences:
          json['notificationPreferences'] != null
              ? Map<String, bool>.from(json['notificationPreferences'])
              : null,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      lastActive: (json['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role.toJson(),
      'teamIds': teamIds,
      'status': status.toJson(),
      'googleCalendarConnected': googleCalendarConnected,
      if (googleAccessToken != null) 'googleAccessToken': googleAccessToken,
      if (googleRefreshToken != null) 'googleRefreshToken': googleRefreshToken,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (notificationPreferences != null)
        'notificationPreferences': notificationPreferences,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'lastActive':
          lastActive != null
              ? Timestamp.fromDate(lastActive!)
              : FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    List<String>? teamIds,
    UserStatus? status,
    bool? googleCalendarConnected,
    String? googleAccessToken,
    String? googleRefreshToken,
    String? fcmToken,
    String? avatarUrl,
    Map<String, bool>? notificationPreferences,
    DateTime? createdAt,
    DateTime? lastActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      teamIds: teamIds ?? this.teamIds,
      status: status ?? this.status,
      googleCalendarConnected:
          googleCalendarConnected ?? this.googleCalendarConnected,
      googleAccessToken: googleAccessToken ?? this.googleAccessToken,
      googleRefreshToken: googleRefreshToken ?? this.googleRefreshToken,
      fcmToken: fcmToken ?? this.fcmToken,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
