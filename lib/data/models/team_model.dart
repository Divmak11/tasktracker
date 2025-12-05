import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String adminId;
  final List<String> memberIds;
  final String createdBy;
  final DateTime? createdAt;

  TeamModel({
    required this.id,
    required this.name,
    required this.adminId,
    this.memberIds = const [],
    required this.createdBy,
    this.createdAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json, String id) {
    return TeamModel(
      id: id,
      name: json['name'] as String,
      adminId: json['adminId'] as String,
      memberIds: List<String>.from(json['memberIds'] ?? []),
      createdBy: json['createdBy'] as String,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'adminId': adminId,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
