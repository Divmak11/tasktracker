import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/approval_request_model.dart';
import '../models/reschedule_log_model.dart';
import '../services/cloud_functions_service.dart';

class ApprovalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  static const String _approvalCollection = 'approval_requests';
  static const String _rescheduleLogCollection = 'reschedule_logs';

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
