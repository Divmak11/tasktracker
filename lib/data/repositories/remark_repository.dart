import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/remark_model.dart';
import '../services/cloud_functions_service.dart';

class RemarkRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final String _collection = 'remarks';

  /// Add a remark to a task via Cloud Function
  Future<String> addRemark({
    required String taskId,
    required String userId,
    required String message,
  }) async {
    // Validate message locally first
    final validationError = RemarkModel.validateMessage(message);
    if (validationError != null) {
      throw Exception(validationError);
    }

    // Call Cloud Function to add remark with proper validation and notifications
    final result = await _cloudFunctions.addRemark(
      taskId: taskId,
      message: message.trim(),
    );
    return result['remarkId'] as String? ?? '';
  }

  /// Get remarks for a task (real-time stream)
  Stream<List<RemarkModel>> getTaskRemarksStream(String taskId) {
    return _firestore
        .collection(_collection)
        .where('taskId', isEqualTo: taskId)
        .orderBy('createdAt', descending: true) // Newest first
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => RemarkModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Get single remark
  Future<RemarkModel?> getRemark(String remarkId) async {
    final doc = await _firestore.collection(_collection).doc(remarkId).get();
    if (!doc.exists) return null;
    return RemarkModel.fromJson(doc.data()!, doc.id);
  }

  /// Delete remark (admin only - future enhancement)
  Future<void> deleteRemark(String remarkId) async {
    await _firestore.collection(_collection).doc(remarkId).delete();
  }

  /// Get remark count for a task
  Future<int> getRemarkCount(String taskId) async {
    final snapshot =
        await _firestore
            .collection(_collection)
            .where('taskId', isEqualTo: taskId)
            .count()
            .get();
    return snapshot.count ?? 0;
  }
}
