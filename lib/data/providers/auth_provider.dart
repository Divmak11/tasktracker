import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../core/constants/env_config.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../services/fcm_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final FCMService _fcmService = FCMService();

  UserModel? _currentUser;
  bool _isLoading = false;
  StreamSubscription? _authStateSubscription;
  StreamSubscription? _userDataSubscription;

  AuthProvider({AuthRepository? authRepository, UserRepository? userRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      _userRepository = userRepository ?? UserRepository() {
    _initAuthListener();
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  UserRole? get userRole => _currentUser?.role;
  UserStatus? get userStatus => _currentUser?.status;
  bool get isSuperAdmin => _currentUser?.role == UserRole.superAdmin;
  bool get isTeamAdmin => _currentUser?.role == UserRole.teamAdmin;
  bool get isMember => _currentUser?.role == UserRole.member;
  bool get isPending => _currentUser?.status == UserStatus.pending;
  bool get isActive => _currentUser?.status == UserStatus.active;

  /// Initialize Firebase auth state listener
  void _initAuthListener() {
    _authStateSubscription = _authRepository.authStateChanges.listen((
      firebase_auth.User? firebaseUser,
    ) {
      if (firebaseUser == null) {
        _clearUser();
      } else {
        _loadUserData(firebaseUser.uid);
      }
    });
  }

  /// Load user data from Firestore
  Future<void> _loadUserData(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔍 Loading user data for: $userId');

      // Cancel previous subscription if any
      await _userDataSubscription?.cancel();

      // First check if user document exists
      final existingUser = await _userRepository.getUser(userId);

      if (existingUser == null) {
        debugPrint('⚠️ User document not found. Creating new user...');

        // Get Firebase user info
        final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          debugPrint('❌ Firebase user is null!');
          _isLoading = false;
          notifyListeners();
          return;
        }

        // Check if user is super admin (supports multiple emails)
        final isSuperAdmin = EnvConfig.isSuperAdminEmail(firebaseUser.email);

        // Create new user document
        final newUser = UserModel(
          id: userId,
          name:
              firebaseUser.displayName ??
              firebaseUser.email?.split('@')[0] ??
              'User',
          email: firebaseUser.email ?? '',
          role: isSuperAdmin ? UserRole.superAdmin : UserRole.member,
          status: isSuperAdmin ? UserStatus.active : UserStatus.pending,
          teamIds: [],
          googleCalendarConnected: false,
        );

        debugPrint(
          '✅ Creating user: ${newUser.email} with role: ${newUser.role}, status: ${newUser.status}',
        );
        await _userRepository.createUser(newUser);
        debugPrint('✅ User document created successfully');
      }

      // Listen to user document changes
      _userDataSubscription = _userRepository
          .getUserStream(userId)
          .listen(
            (UserModel? user) {
              debugPrint(
                '📥 User data received: ${user?.email} (status: ${user?.status})',
              );
              _currentUser = user;
              _isLoading = false;

              // Initialize FCM if user is active
              if (user?.status == UserStatus.active) {
                _fcmService.initialize(userId);
              }

              notifyListeners();
            },
            onError: (error) {
              debugPrint('❌ Error loading user data: $error');
              _isLoading = false;
              notifyListeners();
            },
          );
    } catch (e) {
      debugPrint('❌ Error setting up user stream: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    debugPrint('🔐 Starting Google Sign-In...');
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.signInWithGoogle();
      debugPrint('✅ Google Sign-In successful');
      // User data will be loaded automatically via auth state listener
    } catch (e) {
      debugPrint('❌ Google Sign-In failed: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<void> signInWithApple() async {
    debugPrint('🔐 Starting Apple Sign-In...');
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.signInWithApple();
      debugPrint('✅ Apple Sign-In successful');
      // User data will be loaded automatically via auth state listener
    } catch (e) {
      debugPrint('❌ Apple Sign-In failed: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign out
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.signOut();
      _clearUser();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Clear user data
  void _clearUser() {
    _currentUser = null;
    _isLoading = false;
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
    _fcmService.reset(); // Reset FCM state on logout
    notifyListeners();
  }

  /// Delete account
  Future<void> deleteAccount() async {
    if (_currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Delete user document from Firestore
      await _userRepository.deleteUser(_currentUser!.id);

      // Delete Firebase Auth account
      await _authRepository.deleteAccount();

      _clearUser();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _userDataSubscription?.cancel();
    super.dispose();
  }
}
