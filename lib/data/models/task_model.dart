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
  final String assignedTo;
  final String createdBy;
  final TaskStatus status;
  final DateTime deadline;
  final String? calendarEventId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assignedType,
    required this.assignedTo,
    required this.createdBy,
    required this.status,
    required this.deadline,
    this.calendarEventId,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json, String id) {
    return TaskModel(
      id: id,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      assignedType: TaskAssignedType.fromJson(json['assignedType'] as String),
      assignedTo: json['assignedTo'] as String,
      createdBy: json['createdBy'] as String,
      status: TaskStatus.fromJson(json['status'] as String),
      deadline: (json['deadline'] as Timestamp).toDate(),
      calendarEventId: json['calendarEventId'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'assignedType': assignedType.toJson(),
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'status': status.toJson(),
      'deadline': Timestamp.fromDate(deadline),
      if (calendarEventId != null) 'calendarEventId': calendarEventId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  bool get isOverdue => deadline.isBefore(DateTime.now()) && status == TaskStatus.ongoing;
}
