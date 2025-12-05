import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  // Singleton pattern
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  String? _currentUserId;

  /// Initialize FCM and request permissions (only once per user)
  Future<void> initialize(String userId) async {
    // Prevent re-initialization for same user
    if (_isInitialized && _currentUserId == userId) {
      return;
    }

    _currentUserId = userId;
    _isInitialized = true;

    bool hasPermission = false;

    // For Android 13+ (API 33+), explicitly request POST_NOTIFICATIONS permission
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      hasPermission = status.isGranted;
      debugPrint('Android notification permission: $status');
    } else {
      // For iOS, use Firebase's built-in permission request
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      hasPermission =
          settings.authorizationStatus == AuthorizationStatus.authorized;
    }

    if (hasPermission) {
      debugPrint('User granted notification permission');

      // Get token
      String? token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(userId, token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(userId, newToken);
      });
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }
  }

  /// Save FCM token to user document
  Future<void> _saveTokenToDatabase(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Request permission explicitly (e.g. from settings)
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Reset initialization state (call on logout)
  void reset() {
    _isInitialized = false;
    _currentUserId = null;
  }
}
