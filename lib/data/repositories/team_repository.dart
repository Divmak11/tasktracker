import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_model.dart';
import '../services/cloud_functions_service.dart';

class TeamRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final String _collection = 'teams';

  /// Create a new team via Cloud Function
  Future<String> createTeam(TeamModel team) async {
    final result = await _cloudFunctions.createTeam(
      name: team.name,
      memberIds: team.memberIds,
      adminId: team.adminId,
    );
    return result['teamId'] as String;
  }

  /// Get a team by ID
  Future<TeamModel?> getTeam(String teamId) async {
    final doc = await _firestore.collection(_collection).doc(teamId).get();
    if (!doc.exists) return null;
    return TeamModel.fromJson(doc.data()!, doc.id);
  }

  /// Get team stream (real-time)
  Stream<TeamModel?> getTeamStream(String teamId) {
    return _firestore.collection(_collection).doc(teamId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return TeamModel.fromJson(doc.data()!, doc.id);
    });
  }

  /// Get all teams stream (real-time)
  Stream<List<TeamModel>> getAllTeamsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TeamModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Get teams for a specific user
  Stream<List<TeamModel>> getUserTeamsStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('memberIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TeamModel.fromJson(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Update team via Cloud Function
  Future<void> updateTeam(String teamId, Map<String, dynamic> updates) async {
    await _cloudFunctions.updateTeam(
      teamId: teamId,
      name: updates['name'] as String?,
      memberIds:
          updates['memberIds'] != null
              ? List<String>.from(updates['memberIds'])
              : null,
      adminId: updates['adminId'] as String?,
    );
  }

  /// Delete team via Cloud Function (includes cleanup)
  Future<void> deleteTeam(String teamId) async {
    await _cloudFunctions.deleteTeam(teamId);
  }

  /// Add member to team via Cloud Function
  Future<void> addMember(String teamId, String userId) async {
    final team = await getTeam(teamId);
    if (team == null) return;

    final updatedMembers = [...team.memberIds, userId];
    await _cloudFunctions.updateTeam(teamId: teamId, memberIds: updatedMembers);
  }

  /// Remove member from team via Cloud Function
  Future<void> removeMember(String teamId, String userId) async {
    final team = await getTeam(teamId);
    if (team == null) return;

    final updatedMembers = team.memberIds.where((id) => id != userId).toList();
    await _cloudFunctions.updateTeam(teamId: teamId, memberIds: updatedMembers);
  }
}
