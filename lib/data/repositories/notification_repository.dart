import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'notifications';

  /// Get notifications stream for a user
  Stream<List<NotificationModel>> getUserNotificationsStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => NotificationModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Get unread notifications count
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Create a notification
  Future<void> createNotification(NotificationModel notification) async {
    await _firestore.collection(_collection).add(notification.toJson());
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'isRead': true,
    });
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot =
        await _firestore
            .collection(_collection)
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).delete();
  }

  /// Clear all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    final batch = _firestore.batch();
    final snapshot =
        await _firestore
            .collection(_collection)
            .where('userId', isEqualTo: userId)
            .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Create task assignment notification
  Future<void> notifyTaskAssigned({
    required String userId,
    required String taskId,
    required String taskTitle,
    required String assignerName,
  }) async {
    await createNotification(
      NotificationModel(
        id: '',
        userId: userId,
        type: NotificationType.taskAssigned,
        title: 'New Task Assigned',
        message: '$assignerName assigned you: $taskTitle',
        taskId: taskId,
      ),
    );
  }

  /// Create reschedule approved notification
  Future<void> notifyRescheduleApproved({
    required String userId,
    required String taskId,
    required String taskTitle,
  }) async {
    await createNotification(
      NotificationModel(
        id: '',
        userId: userId,
        type: NotificationType.rescheduleApproved,
        title: 'Reschedule Approved',
        message: 'Your reschedule request for "$taskTitle" was approved',
        taskId: taskId,
      ),
    );
  }

  /// Create reschedule rejected notification
  Future<void> notifyRescheduleRejected({
    required String userId,
    required String taskId,
    required String taskTitle,
  }) async {
    await createNotification(
      NotificationModel(
        id: '',
        userId: userId,
        type: NotificationType.rescheduleRejected,
        title: 'Reschedule Rejected',
        message: 'Your reschedule request for "$taskTitle" was rejected',
        taskId: taskId,
      ),
    );
  }

  /// Create user approved notification
  Future<void> notifyUserApproved(String userId) async {
    await createNotification(
      NotificationModel(
        id: '',
        userId: userId,
        type: NotificationType.userApproved,
        title: 'Account Approved',
        message: 'Your account has been approved. Welcome!',
      ),
    );
  }
}
