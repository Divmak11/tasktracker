import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  taskAssigned,
  taskUpdated,
  taskCompleted,
  taskCancelled,
  rescheduleRequest,
  rescheduleApproved,
  rescheduleRejected,
  userApproved,
  deadlineReminder,
  taskOverdue,
  remark;

  String toJson() => name;

  static NotificationType fromJson(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => NotificationType.taskAssigned,
    );
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? taskId;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.taskId,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json, String id) {
    return NotificationModel(
      id: id,
      userId: json['userId'] as String,
      type: NotificationType.fromJson(json['type'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      taskId: json['taskId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type.toJson(),
      'title': title,
      'message': message,
      if (taskId != null) 'taskId': taskId,
      'isRead': isRead,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    String? taskId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      taskId: taskId ?? this.taskId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
