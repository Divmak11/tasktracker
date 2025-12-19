import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/task_assignment_model.dart';
import '../services/cloud_functions_service.dart';

class TaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final String _collection = 'tasks';
  final String _assignmentsCollection = 'assignments';

  /// Create a new task via Cloud Function
  /// Supports both single and multi-assignee tasks
  Future<String> createTask(
    TaskModel task, {
    List<String>? supervisorIds,
  }) async {
    final result = await _cloudFunctions.assignTask(
      title: task.title,
      subtitle: task.subtitle,
      assignedType: task.assignedType.name,
      assignedTo: task.allAssigneeIds,
      deadline: task.deadline,
      supervisorIds: supervisorIds,
    );
    return result['taskId'] as String? ?? '';
  }

  /// Create a multi-assignee task with explicit assignee list
  Future<String> createMultiAssigneeTask({
    required String title,
    required String subtitle,
    required List<String> assigneeIds,
    required DateTime deadline,
    List<String>? supervisorIds,
    String? teamId,
  }) async {
    final assignedType = teamId != null ? 'team' : 'member';
    final assignedTo = teamId ?? assigneeIds;

    final result = await _cloudFunctions.assignTask(
      title: title,
      subtitle: subtitle,
      assignedType: assignedType,
      assignedTo: assignedTo,
      deadline: deadline,
      supervisorIds: supervisorIds,
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
    // Handle deadline - can be DateTime or Timestamp depending on caller
    DateTime? deadlineValue;
    if (updates['deadline'] != null) {
      final deadline = updates['deadline'];
      if (deadline is DateTime) {
        deadlineValue = deadline;
      } else if (deadline is Timestamp) {
        deadlineValue = deadline.toDate();
      }
    }

    await _cloudFunctions.updateTask(
      taskId: taskId,
      title: updates['title'] as String?,
      subtitle: updates['subtitle'] as String?,
      deadline: deadlineValue,
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

  /// Get all active/ongoing tasks stream (for admin dashboard)
  Stream<List<TaskModel>> getAllActiveTasksStream() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: TaskStatus.ongoing.name)
        .orderBy('deadline', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TaskModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  // ============================================
  // MULTI-ASSIGNEE TASK METHODS
  // ============================================

  /// Get task assignments for a specific task (multi-assignee tasks only)
  Stream<List<TaskAssignmentModel>> getTaskAssignmentsStream(String taskId) {
    return _firestore
        .collection(_collection)
        .doc(taskId)
        .collection(_assignmentsCollection)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => TaskAssignmentModel.fromJson(doc.data(), doc.id),
                  )
                  .toList(),
        );
  }

  /// Get a specific user's assignment for a task
  Future<TaskAssignmentModel?> getUserAssignment(
    String taskId,
    String userId,
  ) async {
    final snapshot =
        await _firestore
            .collection(_collection)
            .doc(taskId)
            .collection(_assignmentsCollection)
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) return null;
    return TaskAssignmentModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }

  /// Get all tasks where user is an assignee (handles both old and new structure)
  /// For old tasks: queries assignedTo field
  /// For new multi-assignee tasks: queries assigneeIds array
  Stream<List<TaskModel>> getUserAssignedTasksStream(
    String userId, {
    TaskStatus? status,
  }) {
    // Query for legacy single-assignee tasks
    Query legacyQuery = _firestore
        .collection(_collection)
        .where('assignedTo', isEqualTo: userId);

    if (status != null) {
      legacyQuery = legacyQuery.where('status', isEqualTo: status.name);
    }

    // Query for new multi-assignee tasks
    Query multiQuery = _firestore
        .collection(_collection)
        .where('assigneeIds', arrayContains: userId);

    if (status != null) {
      multiQuery = multiQuery.where('status', isEqualTo: status.name);
    }

    // Combine both streams
    return legacyQuery.snapshots().asyncMap((legacySnapshot) async {
      final multiSnapshot = await multiQuery.get();

      final legacyTasks =
          legacySnapshot.docs
              .map(
                (doc) => TaskModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

      final multiTasks =
          multiSnapshot.docs
              .map(
                (doc) => TaskModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

      // Combine and remove duplicates by ID
      final allTasks = <String, TaskModel>{};
      for (final task in legacyTasks) {
        allTasks[task.id] = task;
      }
      for (final task in multiTasks) {
        allTasks[task.id] = task;
      }

      // Sort by deadline
      final result = allTasks.values.toList();
      result.sort((a, b) => a.deadline.compareTo(b.deadline));
      return result;
    });
  }

  /// Complete an assignment for a multi-assignee task
  Future<Map<String, dynamic>> completeAssignment(
    String taskId, {
    String? remark,
  }) async {
    return await _cloudFunctions.completeAssignment(taskId, remark: remark);
  }

  /// Get ongoing tasks for user (supports both legacy and multi-assignee)
  Stream<List<TaskModel>> getOngoingAssignedTasksStream(String userId) {
    return getUserAssignedTasksStream(userId, status: TaskStatus.ongoing);
  }

  /// Get past tasks for user (completed or cancelled, supports both structures)
  Stream<List<TaskModel>> getPastAssignedTasksStream(String userId) {
    // Query for legacy single-assignee tasks (completed or cancelled)
    final legacyQuery = _firestore
        .collection(_collection)
        .where('assignedTo', isEqualTo: userId)
        .where(
          'status',
          whereIn: [TaskStatus.completed.name, TaskStatus.cancelled.name],
        );

    // Query for new multi-assignee tasks (completed or cancelled)
    final multiQueryCompleted = _firestore
        .collection(_collection)
        .where('assigneeIds', arrayContains: userId)
        .where('status', isEqualTo: TaskStatus.completed.name);

    final multiQueryCancelled = _firestore
        .collection(_collection)
        .where('assigneeIds', arrayContains: userId)
        .where('status', isEqualTo: TaskStatus.cancelled.name);

    // Combine all streams
    return legacyQuery.snapshots().asyncMap((legacySnapshot) async {
      final multiCompletedSnapshot = await multiQueryCompleted.get();
      final multiCancelledSnapshot = await multiQueryCancelled.get();

      final allTasks = <String, TaskModel>{};

      // Add legacy tasks
      for (final doc in legacySnapshot.docs) {
        final task = TaskModel.fromJson(doc.data(), doc.id);
        allTasks[task.id] = task;
      }

      // Add multi-assignee completed tasks
      for (final doc in multiCompletedSnapshot.docs) {
        final task = TaskModel.fromJson(doc.data(), doc.id);
        allTasks[task.id] = task;
      }

      // Add multi-assignee cancelled tasks
      for (final doc in multiCancelledSnapshot.docs) {
        final task = TaskModel.fromJson(doc.data(), doc.id);
        allTasks[task.id] = task;
      }

      // Sort by deadline descending (most recent first for past tasks)
      final result = allTasks.values.toList();
      result.sort((a, b) => b.deadline.compareTo(a.deadline));
      return result;
    });
  }
}
