import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

/// Custom exception for cloud function timeout
class CloudFunctionTimeoutException implements Exception {
  final String functionName;
  final Duration timeout;

  CloudFunctionTimeoutException(this.functionName, this.timeout);

  @override
  String toString() =>
      'Request timed out after ${timeout.inSeconds}s. Please check your connection and try again.';
}

/// Service to interact with Firebase Cloud Functions
/// Handles all backend API calls for write operations
class CloudFunctionsService {
  static final CloudFunctionsService _instance =
      CloudFunctionsService._internal();
  factory CloudFunctionsService() => _instance;
  CloudFunctionsService._internal();

  // Default timeout for cloud function calls
  static const Duration _defaultTimeout = Duration(seconds: 30);

  // Use asia-south1 region for all Cloud Functions
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  /// Wrapper to call cloud functions with timeout
  Future<T> _callWithTimeout<T>(
    Future<T> Function() call,
    String functionName, {
    Duration? timeout,
  }) async {
    try {
      return await call().timeout(
        timeout ?? _defaultTimeout,
        onTimeout: () {
          throw CloudFunctionTimeoutException(
            functionName,
            timeout ?? _defaultTimeout,
          );
        },
      );
    } on TimeoutException {
      throw CloudFunctionTimeoutException(
        functionName,
        timeout ?? _defaultTimeout,
      );
    }
  }

  // ============================================
  // USER MANAGEMENT
  // ============================================

  /// Approve a pending user's access request (Super Admin only)
  Future<Map<String, dynamic>> approveUserAccess(String userId) async {
    final callable = _functions.httpsCallable('approveUserAccess');
    final result = await callable.call({'userId': userId});
    return Map<String, dynamic>.from(result.data);
  }

  /// Reject a pending user's access request (Super Admin only)
  Future<Map<String, dynamic>> rejectUserAccess(
    String userId, {
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('rejectUserAccess');
    final result = await callable.call({
      'userId': userId,
      if (reason != null) 'reason': reason,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Update a user's role (Super Admin only)
  Future<Map<String, dynamic>> updateUserRole(
    String userId,
    String newRole,
  ) async {
    final callable = _functions.httpsCallable('updateUserRole');
    final result = await callable.call({'userId': userId, 'newRole': newRole});
    return Map<String, dynamic>.from(result.data);
  }

  /// Revoke a user's access - soft delete (Super Admin only)
  Future<Map<String, dynamic>> revokeUserAccess(String userId) async {
    final callable = _functions.httpsCallable('revokeUserAccess');
    final result = await callable.call({'userId': userId});
    return Map<String, dynamic>.from(result.data);
  }

  /// Restore a revoked user's access (Super Admin only)
  Future<Map<String, dynamic>> restoreUserAccess(String userId) async {
    final callable = _functions.httpsCallable('restoreUserAccess');
    final result = await callable.call({'userId': userId});
    return Map<String, dynamic>.from(result.data);
  }



  /// Permanently delete a user and cleanup related data (Super Admin only)
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    final callable = _functions.httpsCallable('deleteUser');
    final result = await callable.call({'userId': userId});
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // TEAM MANAGEMENT
  // ============================================

  /// Create a new team (Super Admin only)
  Future<Map<String, dynamic>> createTeam({
    required String name,
    required List<String> memberIds,
    required String adminId,
  }) async {
    final callable = _functions.httpsCallable('createTeam');
    final result = await callable.call({
      'name': name,
      'memberIds': memberIds,
      'adminId': adminId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Update a team (Super Admin or Team Admin)
  Future<Map<String, dynamic>> updateTeam({
    required String teamId,
    String? name,
    List<String>? memberIds,
    String? adminId,
  }) async {
    final callable = _functions.httpsCallable('updateTeam');
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name;
    if (memberIds != null) updates['memberIds'] = memberIds;
    if (adminId != null) updates['adminId'] = adminId;

    final result = await callable.call({'teamId': teamId, 'updates': updates});
    return Map<String, dynamic>.from(result.data);
  }

  /// Delete a team and cleanup related data (Super Admin only)
  Future<Map<String, dynamic>> deleteTeam(String teamId) async {
    final callable = _functions.httpsCallable('deleteTeam');
    final result = await callable.call({'teamId': teamId});
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // TASK MANAGEMENT
  // ============================================

  /// Assign a new task to a member, multiple members, or team
  /// [assignedTo] can be a single ID (String) or list of IDs (List<String>)
  /// [supervisorIds] optional list of user IDs who can see all assignees' status
  Future<Map<String, dynamic>> assignTask({
    required String title,
    required String subtitle,
    required String assignedType,
    required dynamic assignedTo, // String or List<String>
    required DateTime deadline,
    List<String>? supervisorIds,
  }) async {
    return _callWithTimeout(() async {
      final callable = _functions.httpsCallable('assignTask');
      final result = await callable.call({
        'title': title,
        'subtitle': subtitle,
        'assignedType': assignedType,
        'assignedTo': assignedTo,
        'deadline': deadline.toUtc().toIso8601String(),
        if (supervisorIds != null && supervisorIds.isNotEmpty)
          'supervisorIds': supervisorIds,
      });
      return Map<String, dynamic>.from(result.data);
    }, 'assignTask');
  }

  /// Update a task (title, subtitle, deadline)
  Future<Map<String, dynamic>> updateTask({
    required String taskId,
    String? title,
    String? subtitle,
    DateTime? deadline,
  }) async {
    return _callWithTimeout(() async {
      final callable = _functions.httpsCallable('updateTask');
      final result = await callable.call({
        'taskId': taskId,
        'updates': {
          if (title != null) 'title': title,
          if (subtitle != null) 'subtitle': subtitle,
          if (deadline != null) 'deadline': deadline.toIso8601String(),
        },
      });
      return Map<String, dynamic>.from(result.data);
    }, 'updateTask');
  }

  /// Mark a task as completed (Assignee only)
  /// Works for both single-assignee and multi-assignee tasks
  Future<Map<String, dynamic>> completeTask(
    String taskId, {
    String? remark,
  }) async {
    return _callWithTimeout(() async {
      final callable = _functions.httpsCallable('completeTask');
      final result = await callable.call({
        'taskId': taskId,
        if (remark != null) 'remark': remark,
      });
      return Map<String, dynamic>.from(result.data);
    }, 'completeTask');
  }

  /// Complete an assignment for multi-assignee tasks
  /// Each assignee can complete their own assignment independently
  Future<Map<String, dynamic>> completeAssignment(
    String taskId, {
    String? remark,
  }) async {
    return _callWithTimeout(() async {
      final callable = _functions.httpsCallable('completeAssignment');
      final result = await callable.call({
        'taskId': taskId,
        if (remark != null) 'remark': remark,
      });
      return Map<String, dynamic>.from(result.data);
    }, 'completeAssignment');
  }

  /// Cancel a task (Creator or Super Admin)
  Future<Map<String, dynamic>> cancelTask(String taskId) async {
    final callable = _functions.httpsCallable('cancelTask');
    final result = await callable.call({'taskId': taskId});
    return Map<String, dynamic>.from(result.data);
  }

  /// Reopen a completed/cancelled task (Super Admin only)
  Future<Map<String, dynamic>> reopenTask(
    String taskId,
    DateTime newDeadline,
  ) async {
    final callable = _functions.httpsCallable('reopenTask');
    final result = await callable.call({
      'taskId': taskId,
      'newDeadline': newDeadline.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // RESCHEDULE WORKFLOW
  // ============================================

  /// Request to reschedule a task deadline (Assignee only)
  Future<Map<String, dynamic>> requestReschedule({
    required String taskId,
    required DateTime newDeadline,
    String? reason,
  }) async {
    return _callWithTimeout(() async {
      final callable = _functions.httpsCallable('requestReschedule');
      final result = await callable.call({
        'taskId': taskId,
        'newDeadline': newDeadline.toUtc().toIso8601String(),
        if (reason != null) 'reason': reason,
      });
      return Map<String, dynamic>.from(result.data);
    }, 'requestReschedule');
  }

  /// Approve or reject a reschedule request (Task creator only)
  Future<Map<String, dynamic>> approveReschedule({
    required String requestId,
    required bool approved,
  }) async {
    final callable = _functions.httpsCallable('approveReschedule');
    final result = await callable.call({
      'requestId': requestId,
      'approved': approved,
    });
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // REMARK MANAGEMENT
  // ============================================

  /// Add a remark to a task
  Future<Map<String, dynamic>> addRemark({
    required String taskId,
    required String message,
  }) async {
    final callable = _functions.httpsCallable('addRemark');
    final result = await callable.call({'taskId': taskId, 'message': message});
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // CALENDAR MANAGEMENT
  // ============================================

  /// Disconnect Google Calendar
  Future<Map<String, dynamic>> disconnectCalendar() async {
    final callable = _functions.httpsCallable('disconnectCalendar');
    final result = await callable.call();
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // PROFILE MANAGEMENT
  // ============================================

  /// Update user profile (name, avatar, notification preferences)
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? avatarUrl,
    Map<String, bool>? notificationPreferences,
  }) async {
    final callable = _functions.httpsCallable('updateProfile');
    final result = await callable.call({
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (notificationPreferences != null)
        'notificationPreferences': notificationPreferences,
    });
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // INVITE MANAGEMENT
  // ============================================

  /// Send an invite to a new user (Super Admin only)
  Future<Map<String, dynamic>> sendInvite({
    required String email,
    String? teamId,
  }) async {
    final callable = _functions.httpsCallable('sendInvite');
    final result = await callable.call({
      'email': email,
      if (teamId != null) 'teamId': teamId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Resend an invite email (Super Admin only)
  Future<Map<String, dynamic>> resendInvite(String inviteId) async {
    final callable = _functions.httpsCallable('resendInvite');
    final result = await callable.call({'inviteId': inviteId});
    return Map<String, dynamic>.from(result.data);
  }

  /// Cancel a pending invite (Super Admin only)
  Future<Map<String, dynamic>> cancelInvite(String inviteId) async {
    final callable = _functions.httpsCallable('cancelInvite');
    final result = await callable.call({'inviteId': inviteId});
    return Map<String, dynamic>.from(result.data);
  }

  /// Validate an invite token (public)
  Future<Map<String, dynamic>> validateInviteToken(String token) async {
    final callable = _functions.httpsCallable('validateInviteToken');
    final result = await callable.call({'token': token});
    return Map<String, dynamic>.from(result.data);
  }

  /// Accept an invite after sign up
  Future<Map<String, dynamic>> acceptInvite(String token) async {
    final callable = _functions.httpsCallable('acceptInvite');
    final result = await callable.call({'token': token});
    return Map<String, dynamic>.from(result.data);
  }

  /// Get all invites (Super Admin only)
  Future<Map<String, dynamic>> getInvites({String? status}) async {
    final callable = _functions.httpsCallable('getInvites');
    final result = await callable.call({if (status != null) 'status': status});
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // ACCOUNT MANAGEMENT
  // ============================================

  /// Delete own account and all associated data (Play Store compliance)
  Future<Map<String, dynamic>> deleteOwnAccount() async {
    final callable = _functions.httpsCallable('deleteOwnAccount');
    final result = await callable.call();
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // REPORT EXPORT
  // ============================================

  /// Export tasks report as PDF (Super Admin only)
  Future<Map<String, dynamic>> exportReport({
    required DateTime startDate,
    required DateTime endDate,
    String? teamId,
    String? status,
  }) async {
    final callable = _functions.httpsCallable('exportReport');
    final result = await callable.call({
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      if (teamId != null) 'teamId': teamId,
      if (status != null) 'status': status,
    });
    return Map<String, dynamic>.from(result.data);
  }

  // ============================================
  // CALENDAR FUNCTIONS
  // ============================================

  /// Exchange Google OAuth auth code for access and refresh tokens.
  ///
  /// This is called after GoogleSignIn returns a serverAuthCode.
  /// The backend exchanges this code for a REAL refresh_token that allows
  /// automatic token refresh without user interaction.
  Future<Map<String, dynamic>> exchangeCalendarAuthCode(String authCode) async {
    final callable = _functions.httpsCallable('exchangeCalendarAuthCode');
    final result = await callable.call({'authCode': authCode});
    return Map<String, dynamic>.from(result.data);
  }
}
