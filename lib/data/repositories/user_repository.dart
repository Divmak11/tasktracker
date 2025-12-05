import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/cloud_functions_service.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();

  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get user document stream
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      return UserModel.fromJson(snapshot.data()!, snapshot.id);
    });
  }

  /// Get user document once
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data()!, doc.id);
  }

  /// Create user document
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toJson());
  }

  /// Update user document
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }

  /// Delete user via Cloud Function (includes cleanup)
  Future<void> deleteUser(String userId) async {
    await _cloudFunctions.deleteUser(userId);
  }

  /// Approve pending user access (Super Admin only)
  Future<void> approveUserAccess(String userId) async {
    await _cloudFunctions.approveUserAccess(userId);
  }

  /// Reject pending user access (Super Admin only)
  Future<void> rejectUserAccess(String userId, {String? reason}) async {
    await _cloudFunctions.rejectUserAccess(userId, reason: reason);
  }

  /// Update user role via Cloud Function (Super Admin only)
  Future<void> updateUserRole(String userId, String newRole) async {
    await _cloudFunctions.updateUserRole(userId, newRole);
  }

  /// Revoke user access (Super Admin only)
  Future<void> revokeUserAccess(String userId) async {
    await _cloudFunctions.revokeUserAccess(userId);
  }

  /// Get all users (for admin)
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs
        .map((doc) => UserModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Stream all users (for admin)
  Stream<List<UserModel>> getAllUsersStream() {
    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => UserModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Update FCM token
  Future<void> updateFcmToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': token,
    });
  }
}
