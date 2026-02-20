import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/approval_request_model.dart';
import '../models/reschedule_log_model.dart';
import '../services/cloud_functions_service.dart';

class ApprovalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  // Must match backend: Collections.APPROVAL_REQUESTS = 'approvalRequests'
  static const String _approvalCollection = 'approvalRequests';
  // Must match backend: Collections.RESCHEDULE_LOG = 'rescheduleLog'
  static const String _rescheduleLogCollection = 'rescheduleLog';

  /// Create a reschedule request via Cloud Function
  Future<String> createRescheduleRequest({
    required String taskId,
    required String requesterId,
    required String taskCreatorId,
    required DateTime originalDeadline,
    required DateTime newDeadline,
    String? reason,
  }) async {
    final result = await _cloudFunctions.requestReschedule(
      taskId: taskId,
      newDeadline: newDeadline,
      reason: reason,
    );
    return result['requestId'] as String? ?? '';
  }

  /// Get pending reschedule requests for tasks created by a user
  Stream<List<ApprovalRequestModel>> getPendingRescheduleRequestsStream(
    String taskCreatorId,
  ) {
    return _firestore
        .collection(_approvalCollection)
        .where('type', isEqualTo: 'reschedule')
        .where('status', isEqualTo: 'pending')
        .where('payload.taskCreatorId', isEqualTo: taskCreatorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ApprovalRequestModel.fromJson(doc.data(), doc.id),
                  )
                  .toList(),
        );
  }

  /// Get pending reschedule request for a specific task
  Stream<ApprovalRequestModel?> getTaskPendingRescheduleStream(String taskId) {
    return _firestore
        .collection(_approvalCollection)
        .where('type', isEqualTo: 'reschedule')
        .where('status', isEqualTo: 'pending')
        .where('targetId', isEqualTo: taskId)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.isNotEmpty
                  ? ApprovalRequestModel.fromJson(
                    snapshot.docs.first.data(),
                    snapshot.docs.first.id,
                  )
                  : null,
        );
  }

  /// Get ALL reschedule requests for a specific task (all statuses), ordered by newest first.
  /// Used to display full reschedule history to task participants.
  ///
  /// FIRESTORE INDEX REQUIRED:
  ///   Collection: approvalRequests
  ///   Fields: type ASC, targetId ASC, createdAt DESC
  ///
  /// SECURITY: Backend Firestore rules must allow task assignees to read
  /// approvalRequests docs where targetId matches their assigned task.
  Stream<List<ApprovalRequestModel>> getTaskRescheduleHistoryStream(
    String taskId,
  ) {
    return _firestore
        .collection(_approvalCollection)
        .where('type', isEqualTo: 'reschedule')
        .where('targetId', isEqualTo: taskId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((Object error) {
          // Gracefully handle missing Firestore composite index (failed-precondition)
          // or insufficient permissions. History section shows empty state.
          debugPrint(
            '[ApprovalRepository] getTaskRescheduleHistoryStream '
            'error for task $taskId: $error',
          );
        })
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) =>
                        ApprovalRequestModel.fromJson(doc.data(), doc.id),
                  )
                  .toList(),
        );
  }

  /// Approve a reschedule request via Cloud Function
  Future<void> approveRescheduleRequest({
    required String requestId,
    required String approverId,
    required String taskId,
    required DateTime newDeadline,
  }) async {
    await _cloudFunctions.approveReschedule(
      requestId: requestId,
      approved: true,
    );
  }

  /// Reject a reschedule request via Cloud Function
  Future<void> rejectRescheduleRequest({
    required String requestId,
    required String approverId,
  }) async {
    await _cloudFunctions.approveReschedule(
      requestId: requestId,
      approved: false,
    );
  }

  /// Get all reschedule requests (for admin)
  Stream<List<ApprovalRequestModel>> getAllRescheduleRequestsStream({
    ApprovalRequestStatus? status,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_approvalCollection)
        .where('type', isEqualTo: 'reschedule');

    if (status != null) {
      query = query.where('status', isEqualTo: status.toJson());
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ApprovalRequestModel.fromJson(doc.data(), doc.id),
                  )
                  .toList(),
        );
  }

  /// Create a reschedule log entry
  Future<void> createRescheduleLog({
    required String taskId,
    required String requestedBy,
    required DateTime originalDeadline,
    required DateTime newDeadline,
    required String approvedBy,
  }) async {
    final docRef = _firestore.collection(_rescheduleLogCollection).doc();

    final log = RescheduleLogModel(
      id: docRef.id,
      taskId: taskId,
      requestedBy: requestedBy,
      originalDeadline: originalDeadline,
      newDeadline: newDeadline,
      approvedBy: approvedBy,
    );

    await docRef.set(log.toJson());
  }

  /// Get reschedule logs (for admin)
  Stream<List<RescheduleLogModel>> getRescheduleLogsStream() {
    return _firestore
        .collection(_rescheduleLogCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => RescheduleLogModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Get count of pending reschedule requests for a user's tasks
  Future<int> getPendingRescheduleCount(String taskCreatorId) async {
    final snapshot =
        await _firestore
            .collection(_approvalCollection)
            .where('type', isEqualTo: 'reschedule')
            .where('status', isEqualTo: 'pending')
            .where('payload.taskCreatorId', isEqualTo: taskCreatorId)
            .count()
            .get();
    return snapshot.count ?? 0;
  }
}
