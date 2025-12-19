import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskAssignedType {
  member,
  team;

  String toJson() => name;

  static TaskAssignedType fromJson(String value) {
    return TaskAssignedType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => TaskAssignedType.member,
    );
  }
}

enum TaskStatus {
  ongoing,
  completed,
  cancelled;

  String toJson() => name;

  static TaskStatus fromJson(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TaskStatus.ongoing,
    );
  }
}

class TaskModel {
  final String id;
  final String title;
  final String subtitle;
  final TaskAssignedType assignedType;
  final String createdBy;
  final TaskStatus status;
  final DateTime deadline;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Legacy single-assignee fields (for backward compatibility)
  final String? assignedTo;
  final String? calendarEventId;
  final DateTime? completedAt;
  final String? completionRemark;

  // New multi-assignee fields
  final bool isMultiAssignee;
  final List<String> assigneeIds;
  final List<String> supervisorIds;
  final String? sourceTeamId;

  TaskModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assignedType,
    required this.createdBy,
    required this.status,
    required this.deadline,
    this.createdAt,
    this.updatedAt,
    // Legacy fields
    this.assignedTo,
    this.calendarEventId,
    this.completedAt,
    this.completionRemark,
    // Multi-assignee fields
    this.isMultiAssignee = false,
    this.assigneeIds = const [],
    this.supervisorIds = const [],
    this.sourceTeamId,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json, String id) {
    final isMulti = json['isMultiAssignee'] as bool? ?? false;

    return TaskModel(
      id: id,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      assignedType: TaskAssignedType.fromJson(json['assignedType'] as String),
      createdBy: json['createdBy'] as String,
      status: TaskStatus.fromJson(json['status'] as String),
      deadline: (json['deadline'] as Timestamp).toDate(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      // Legacy fields
      assignedTo: json['assignedTo'] as String?,
      calendarEventId: json['calendarEventId'] as String?,
      completedAt: (json['completedAt'] as Timestamp?)?.toDate(),
      completionRemark: json['completionRemark'] as String?,
      // Multi-assignee fields
      isMultiAssignee: isMulti,
      assigneeIds:
          (json['assigneeIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      supervisorIds:
          (json['supervisorIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      sourceTeamId: json['sourceTeamId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'assignedType': assignedType.toJson(),
      'createdBy': createdBy,
      'status': status.toJson(),
      'deadline': Timestamp.fromDate(deadline),
      'isMultiAssignee': isMultiAssignee,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (calendarEventId != null) 'calendarEventId': calendarEventId,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'updatedAt':
          updatedAt != null
              ? Timestamp.fromDate(updatedAt!)
              : FieldValue.serverTimestamp(),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (completionRemark != null) 'completionRemark': completionRemark,
      if (assigneeIds.isNotEmpty) 'assigneeIds': assigneeIds,
      if (supervisorIds.isNotEmpty) 'supervisorIds': supervisorIds,
      if (sourceTeamId != null) 'sourceTeamId': sourceTeamId,
    };
  }

  bool get isOverdue =>
      deadline.isBefore(DateTime.now()) && status == TaskStatus.ongoing;

  /// Get the primary assignee ID for display purposes
  /// For single-assignee: returns assignedTo
  /// For multi-assignee: returns first assignee or empty string
  String get primaryAssigneeId {
    if (!isMultiAssignee && assignedTo != null) {
      return assignedTo!;
    }
    return assigneeIds.isNotEmpty ? assigneeIds.first : '';
  }

  /// Get all assignee IDs regardless of task type
  List<String> get allAssigneeIds {
    if (!isMultiAssignee && assignedTo != null) {
      return [assignedTo!];
    }
    return assigneeIds;
  }

  /// Check if a user is the creator of this task
  bool isCreator(String userId) => createdBy == userId;

  /// Check if a user is a supervisor of this task
  bool isSupervisor(String userId) => supervisorIds.contains(userId);

  /// Check if a user is an assignee of this task
  bool isAssignee(String userId) {
    if (!isMultiAssignee) {
      return assignedTo == userId;
    }
    return assigneeIds.contains(userId);
  }

  /// Check if a user can see completion status of all assignees
  /// (Creator or Supervisor can see this)
  bool canSeeAllCompletionStatus(String userId) {
    return isCreator(userId) || isSupervisor(userId);
  }
}
