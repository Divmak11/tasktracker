import 'package:cloud_firestore/cloud_firestore.dart';

enum ApprovalRequestType {
  reschedule,
  userAccess;

  String toJson() => name == 'userAccess' ? 'user_access' : name;

  static ApprovalRequestType fromJson(String value) {
    if (value == 'user_access') return ApprovalRequestType.userAccess;
    return ApprovalRequestType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ApprovalRequestType.userAccess,
    );
  }
}

enum ApprovalRequestStatus {
  pending,
  approved,
  rejected;

  String toJson() => name;

  static ApprovalRequestStatus fromJson(String value) {
    return ApprovalRequestStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ApprovalRequestStatus.pending,
    );
  }
}

class ApprovalRequestModel {
  final String id;
  final ApprovalRequestType type;
  final String requesterId;
  final String targetId;
  final Map<String, dynamic> payload;
  final ApprovalRequestStatus status;
  final String? approverId;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  ApprovalRequestModel({
    required this.id,
    required this.type,
    required this.requesterId,
    required this.targetId,
    this.payload = const {},
    required this.status,
    this.approverId,
    this.createdAt,
    this.resolvedAt,
  });

  factory ApprovalRequestModel.fromJson(Map<String, dynamic> json, String id) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    
    // Convert Timestamp fields in payload to DateTime
    final processedPayload = Map<String, dynamic>.from(payload);
    if (processedPayload['newDeadline'] is Timestamp) {
      processedPayload['newDeadline'] = (processedPayload['newDeadline'] as Timestamp).toDate();
    }
    if (processedPayload['originalDeadline'] is Timestamp) {
      processedPayload['originalDeadline'] = (processedPayload['originalDeadline'] as Timestamp).toDate();
    }

    return ApprovalRequestModel(
      id: id,
      type: ApprovalRequestType.fromJson(json['type'] as String),
      requesterId: json['requesterId'] as String,
      targetId: json['targetId'] as String,
      payload: processedPayload,
      status: ApprovalRequestStatus.fromJson(json['status'] as String),
      approverId: json['approverId'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      resolvedAt: (json['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    final processedPayload = Map<String, dynamic>.from(payload);
    
    // Convert DateTime fields in payload to Timestamp
    if (processedPayload['newDeadline'] is DateTime) {
      processedPayload['newDeadline'] = Timestamp.fromDate(processedPayload['newDeadline'] as DateTime);
    }
    if (processedPayload['originalDeadline'] is DateTime) {
      processedPayload['originalDeadline'] = Timestamp.fromDate(processedPayload['originalDeadline'] as DateTime);
    }

    return {
      'type': type.toJson(),
      'requesterId': requesterId,
      'targetId': targetId,
      'payload': processedPayload,
      'status': status.toJson(),
      if (approverId != null) 'approverId': approverId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
    };
  }

  // Helper getters for common payload fields
  DateTime? get newDeadline => payload['newDeadline'] as DateTime?;
  DateTime? get originalDeadline => payload['originalDeadline'] as DateTime?;
  String? get reason => payload['reason'] as String?;
  String? get email => payload['email'] as String?;
}
