import 'package:cloud_firestore/cloud_firestore.dart';

class RescheduleLogModel {
  final String id;
  final String taskId;
  final String requestedBy;
  final DateTime originalDeadline;
  final DateTime newDeadline;
  final String approvedBy;
  final DateTime? createdAt;

  RescheduleLogModel({
    required this.id,
    required this.taskId,
    required this.requestedBy,
    required this.originalDeadline,
    required this.newDeadline,
    required this.approvedBy,
    this.createdAt,
  });

  factory RescheduleLogModel.fromJson(Map<String, dynamic> json, String id) {
    return RescheduleLogModel(
      id: id,
      taskId: json['taskId'] as String,
      requestedBy: json['requestedBy'] as String,
      originalDeadline: (json['originalDeadline'] as Timestamp).toDate(),
      newDeadline: (json['newDeadline'] as Timestamp).toDate(),
      approvedBy: json['approvedBy'] as String,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'requestedBy': requestedBy,
      'originalDeadline': Timestamp.fromDate(originalDeadline),
      'newDeadline': Timestamp.fromDate(newDeadline),
      'approvedBy': approvedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
