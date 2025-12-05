import 'package:cloud_firestore/cloud_firestore.dart';

class RemarkModel {
  final String id;
  final String taskId;
  final String userId;
  final String message;
  final DateTime? createdAt;

  RemarkModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.message,
    this.createdAt,
  });

  factory RemarkModel.fromJson(Map<String, dynamic> json, String id) {
    return RemarkModel(
      id: id,
      taskId: json['taskId'] as String,
      userId: json['userId'] as String,
      message: json['message'] as String,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'userId': userId,
      'message': message,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  /// Validate remark message
  static String? validateMessage(String? message) {
    if (message == null || message.trim().isEmpty) {
      return 'Message cannot be empty';
    }
    if (message.trim().length > 300) {
      return 'Message must be 300 characters or less';
    }
    return null;
  }
}
