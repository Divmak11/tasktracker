import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// One-time script to upgrade existing super admin users
/// Run this once to fix the status of the super admin email
Future<void> upgradeSuperAdmin() async {
  await dotenv.load();
  final superAdminEmail = dotenv.env['SUPER_ADMIN_EMAIL'];

  if (superAdminEmail == null || superAdminEmail.isEmpty) {
    developer.log('❌ SUPER_ADMIN_EMAIL not found in .env');
    return;
  }

  final firestore = FirebaseFirestore.instance;

  // Find user by email
  final querySnapshot =
      await firestore
          .collection('users')
          .where('email', isEqualTo: superAdminEmail)
          .limit(1)
          .get();

  if (querySnapshot.docs.isEmpty) {
    developer.log('⚠️  No user found with email: $superAdminEmail');
    return;
  }

  final userDoc = querySnapshot.docs.first;
  final userId = userDoc.id;

  // Update to super admin with active status
  await firestore.collection('users').doc(userId).update({
    'role': 'superAdmin',
    'status': 'active',
    'upgradedAt': DateTime.now().toIso8601String(),
  });

  developer.log(
    '✅ Successfully upgraded $superAdminEmail to Super Admin with active status',
  );
  developer.log('   User ID: $userId');
}
