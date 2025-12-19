import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an individual assignment within a multi-assignee task
enum TaskAssignmentStatus {
  ongoing,
  completed;

  String toJson() => name;

  static TaskAssignmentStatus fromJson(String value) {
    return TaskAssignmentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TaskAssignmentStatus.ongoing,
    );
  }
}

/// Represents an individual user's assignment within a multi-assignee task
/// Stored as a subcollection under tasks/{taskId}/assignments/{assignmentId}
class TaskAssignmentModel {
  final String id;
  final String userId;
  final TaskAssignmentStatus status;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final String? completionRemark;
  final String? calendarEventId;

  TaskAssignmentModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.assignedAt,
    this.completedAt,
    this.completionRemark,
    this.calendarEventId,
  });

  factory TaskAssignmentModel.fromJson(Map<String, dynamic> json, String id) {
    return TaskAssignmentModel(
      id: id,
      userId: json['userId'] as String,
      status: TaskAssignmentStatus.fromJson(json['status'] as String),
      assignedAt: (json['assignedAt'] as Timestamp).toDate(),
      completedAt: (json['completedAt'] as Timestamp?)?.toDate(),
      completionRemark: json['completionRemark'] as String?,
      calendarEventId: json['calendarEventId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'status': status.toJson(),
      'assignedAt': Timestamp.fromDate(assignedAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (completionRemark != null) 'completionRemark': completionRemark,
      if (calendarEventId != null) 'calendarEventId': calendarEventId,
    };
  }

  bool get isCompleted => status == TaskAssignmentStatus.completed;

  /// Check if this assignment is overdue based on a task deadline
  bool isOverdue(DateTime taskDeadline) {
    return taskDeadline.isBefore(DateTime.now()) &&
        status == TaskAssignmentStatus.ongoing;
  }
}
