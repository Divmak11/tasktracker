import 'package:cloud_firestore/cloud_firestore.dart';

/// Invite status enum
enum InviteStatus { pending, accepted, expired, cancelled }

/// Extension for InviteStatus
extension InviteStatusExtension on InviteStatus {
  String get value {
    switch (this) {
      case InviteStatus.pending:
        return 'pending';
      case InviteStatus.accepted:
        return 'accepted';
      case InviteStatus.expired:
        return 'expired';
      case InviteStatus.cancelled:
        return 'cancelled';
    }
  }

  static InviteStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return InviteStatus.pending;
      case 'accepted':
        return InviteStatus.accepted;
      case 'expired':
        return InviteStatus.expired;
      case 'cancelled':
        return InviteStatus.cancelled;
      default:
        return InviteStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case InviteStatus.pending:
        return 'Pending';
      case InviteStatus.accepted:
        return 'Accepted';
      case InviteStatus.expired:
        return 'Expired';
      case InviteStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Model representing a user invite
class InviteModel {
  final String id;
  final String email;
  final String invitedBy;
  final String? teamId;
  final String token;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedBy;

  const InviteModel({
    required this.id,
    required this.email,
    required this.invitedBy,
    this.teamId,
    required this.token,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
    this.acceptedBy,
  });

  /// Create from Firestore document
  factory InviteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InviteModel(
      id: doc.id,
      email: data['email'] ?? '',
      invitedBy: data['invitedBy'] ?? '',
      teamId: data['teamId'],
      token: data['token'] ?? '',
      status: InviteStatusExtension.fromString(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      acceptedBy: data['acceptedBy'],
    );
  }

  /// Create from Cloud Function response
  factory InviteModel.fromMap(Map<String, dynamic> map) {
    return InviteModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      invitedBy: map['invitedBy'] ?? '',
      teamId: map['teamId'],
      token: map['token'] ?? '',
      status: InviteStatusExtension.fromString(map['status'] ?? 'pending'),
      createdAt:
          map['createdAt'] != null
              ? DateTime.parse(map['createdAt'])
              : DateTime.now(),
      expiresAt:
          map['expiresAt'] != null
              ? DateTime.parse(map['expiresAt'])
              : DateTime.now(),
      acceptedAt:
          map['acceptedAt'] != null ? DateTime.parse(map['acceptedAt']) : null,
      acceptedBy: map['acceptedBy'],
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'invitedBy': invitedBy,
      'teamId': teamId,
      'token': token,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (acceptedBy != null) 'acceptedBy': acceptedBy,
    };
  }

  /// Check if invite is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if invite can be resent
  bool get canResend => status == InviteStatus.pending;

  /// Check if invite can be cancelled
  bool get canCancel => status == InviteStatus.pending;

  /// Copy with method
  InviteModel copyWith({
    String? id,
    String? email,
    String? invitedBy,
    String? teamId,
    String? token,
    InviteStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? acceptedAt,
    String? acceptedBy,
  }) {
    return InviteModel(
      id: id ?? this.id,
      email: email ?? this.email,
      invitedBy: invitedBy ?? this.invitedBy,
      teamId: teamId ?? this.teamId,
      token: token ?? this.token,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
    );
  }
}
