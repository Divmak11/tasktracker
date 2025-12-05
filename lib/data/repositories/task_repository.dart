import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../services/cloud_functions_service.dart';

class TaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final String _collection = 'tasks';

  /// Create a new task via Cloud Function
  Future<String> createTask(TaskModel task) async {
    final result = await _cloudFunctions.assignTask(
      title: task.title,
      subtitle: task.subtitle,
      assignedType: task.assignedType.name,
      assignedTo: task.assignedTo,
      deadline: task.deadline,
    );
    return result['taskId'] as String? ?? '';
  }

  /// Get a task by ID
  Future<TaskModel?> getTask(String taskId) async {
    final doc = await _firestore.collection(_collection).doc(taskId).get();
    if (!doc.exists) return null;
    return TaskModel.fromJson(doc.data()!, doc.id);
  }

  /// Get task stream (real-time)
  Stream<TaskModel?> getTaskStream(String taskId) {
    return _firestore.collection(_collection).doc(taskId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return TaskModel.fromJson(doc.data()!, doc.id);
    });
  }

  /// Get user's tasks stream with optional status filter
  Stream<List<TaskModel>> getUserTasksStream(
    String userId, {
    TaskStatus? status,
  }) {
    Query query = _firestore
        .collection(_collection)
        .where('assignedTo', isEqualTo: userId)
        .orderBy('deadline', descending: false);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map(
                (doc) => TaskModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
    );
  }

  /// Get ongoing tasks for a user
  Stream<List<TaskModel>> getOngoingTasksStream(String userId) {
    return getUserTasksStream(userId, status: TaskStatus.ongoing);
  }

  /// Get past tasks (completed or cancelled) for a user
  Stream<List<TaskModel>> getPastTasksStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('assignedTo', isEqualTo: userId)
        .where(
          'status',
          whereIn: [TaskStatus.completed.name, TaskStatus.cancelled.name],
        )
        .orderBy('deadline', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TaskModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Get all tasks created by a user
  Stream<List<TaskModel>> getCreatedTasksStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('createdBy', isEqualTo: userId)
        .orderBy('deadline', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TaskModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Update task via Cloud Function
  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    await _cloudFunctions.updateTask(
      taskId: taskId,
      title: updates['title'] as String?,
      subtitle: updates['subtitle'] as String?,
      deadline:
          updates['deadline'] != null
              ? (updates['deadline'] as Timestamp).toDate()
              : null,
    );
  }

  /// Mark task as complete via Cloud Function
  Future<void> completeTask(String taskId, {String? remark}) async {
    await _cloudFunctions.completeTask(taskId, remark: remark);
  }

  /// Cancel task via Cloud Function
  Future<void> cancelTask(String taskId) async {
    await _cloudFunctions.cancelTask(taskId);
  }

  /// Reopen task via Cloud Function (admin only)
  Future<void> reopenTask(String taskId, DateTime newDeadline) async {
    await _cloudFunctions.reopenTask(taskId, newDeadline);
  }

  /// Delete task (hard delete - use sparingly)
  Future<void> deleteTask(String taskId) async {
    await _firestore.collection(_collection).doc(taskId).delete();
  }

  /// Get overdue tasks for admin dashboard
  Stream<List<TaskModel>> getOverdueTasksStream() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: TaskStatus.ongoing.name)
        .where('deadline', isLessThan: Timestamp.now())
        .orderBy('deadline', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TaskModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Get team tasks
  Stream<List<TaskModel>> getTeamTasksStream(String teamId) {
    return _firestore
        .collection(_collection)
        .where('assignedType', isEqualTo: TaskAssignedType.team.name)
        .where('assignedTo', isEqualTo: teamId)
        .orderBy('deadline', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TaskModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Get all tasks stream (for admin dashboard)
  Stream<List<TaskModel>> getAllTasksStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TaskModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }
}
