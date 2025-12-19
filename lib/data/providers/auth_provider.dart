import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../core/constants/env_config.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../services/fcm_service.dart';

class AuthProvider with ChangeNotifier, WidgetsBindingObserver {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final FCMService _fcmService = FCMService();

  UserModel? _currentUser;
  firebase_auth.User? _firebaseUser; // Track Firebase auth state separately
  bool _isLoading = true; // Start as true to show splash while checking auth
  bool _isInitialLoad = true; // Separate flag for initial bootstrap
  StreamSubscription? _authStateSubscription;
  StreamSubscription? _userDataSubscription;

  AuthProvider({AuthRepository? authRepository, UserRepository? userRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      _userRepository = userRepository ?? UserRepository() {
    WidgetsBinding.instance.addObserver(this);
    _initAuthListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed: Refreshing user data and FCM token');
      refreshUser();
      if (_currentUser?.id != null) {
        _fcmService.initialize(_currentUser!.id);
      }
    }
  }



  UserModel? get currentUser => _currentUser;
  firebase_auth.User? get firebaseUser => _firebaseUser;
  bool get isAuthenticated =>
      _firebaseUser != null; // Based on Firebase auth, not Firestore user
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
    // CRITICAL: Check currentUser synchronously BEFORE subscribing to stream
    final restoredUser = _authRepository.currentFirebaseUser;
    if (restoredUser != null) {
      debugPrint(
        '🔐 Initial auth check: Session already restored for ${restoredUser.uid}',
      );
      _firebaseUser = restoredUser;
      _loadUserData(restoredUser.uid);
    } else {
      debugPrint('🔓 Initial auth check: No restored session found');
    }

    // Subscribe to auth state changes for subsequent updates
    _authStateSubscription = _authRepository.authStateChanges.listen((
      firebase_auth.User? firebaseUser,
    ) async {
      // Skip if this is the same user we already handled above
      if (_firebaseUser?.uid == firebaseUser?.uid && _firebaseUser != null) {
        debugPrint('🔄 Auth stream: Same user, skipping duplicate event');
        return;
      }

      _firebaseUser = firebaseUser;

      if (firebaseUser == null) {
        if (_isInitialLoad) {
          // We are in initial load and got a null user.
          // This could be real logout, OR just waiting for silent sign in.
          debugPrint(
            '🤔 Auth stream is null during load. Attempting silent sign-in...',
          );
          await _attemptSilentSignIn();
        } else {
          // Regular sign out
          debugPrint('🔓 Auth state changed: User signed out');
          _clearUser();
        }
      } else {
        debugPrint('🔐 Auth state changed: User signed in ${firebaseUser.uid}');
        _loadUserData(firebaseUser.uid);
      }
    });

    // If we didn't have a restored user, the stream will fire immediately (usually with null)
    // which effectively triggers the logic above. 
    // However, if for some reason the stream doesn't fire immediately, we might hang?
    // FirebaseAuth usually guarantees firing on listen.
  }

  Future<void> _attemptSilentSignIn() async {
    try {
      // Try to sign in silently with Google
      final result = await _authRepository.signInWithGoogleSilently();
      
      if (result?.user != null) {
         debugPrint('✅ Bootstrapping: Silent Google sign-in restored ${result!.user!.uid}');
         // The authStateChanges stream will fire with the new user, so we don't need to do anything here
         return;
      }
      
      debugPrint('🔓 Bootstrapping: No Google session found');
      _clearUser(); // Finalize logout state
    } catch (e) {
      debugPrint('❌ Bootstrapping: Silent Google sign-in failed: $e');
      _clearUser(); // Finalize logout state
    } finally {
      _isInitialLoad = false;
    }
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

              // CRITICAL: If user document was deleted (stream returns null after we had a user)
              // This happens during account deletion - auto-logout to prevent stuck splash
              if (user == null && _currentUser != null && !_isInitialLoad) {
                debugPrint('🚪 User document deleted, auto-logging out...');
                _currentUser = null;
                _isLoading = false;
                notifyListeners();
                // Force logout asynchronously
                logout().catchError((e) {
                  debugPrint('❌ Auto-logout error: $e');
                });
                return;
              }

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
    } finally {
      // CRITICAL: Always mark initial load as complete after first user load attempt
      // This ensures subsequent null events (like from deleteAccount) are treated as logouts
      _isInitialLoad = false;
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

      // Wait for user data to actually load (with timeout)
      await _waitForUserData();

      // Check if user has revoked status
      if (_currentUser?.status == UserStatus.revoked) {
        debugPrint('⚠️ User has revoked status, signing out from Google only');
        // Sign out from Google only to force account picker on next attempt
        // Keep Firebase session so router can navigate to AccessRevokedScreen
        await _authRepository.signOutGoogleOnly();
        _isLoading = false;
        notifyListeners();
        // Don't rethrow - let router handle navigation to AccessRevokedScreen
        return;
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In failed: $e');

      // Always sign out from Google on any error to force account picker on next attempt
      await _authRepository.signOutGoogleOnly();

      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Wait for user data to load with timeout
  Future<void> _waitForUserData() async {
    const maxWait = Duration(seconds: 5);
    const pollInterval = Duration(milliseconds: 100);
    final startTime = DateTime.now();

    while (_currentUser == null &&
        DateTime.now().difference(startTime) < maxWait) {
      await Future.delayed(pollInterval);
    }

    if (_currentUser == null) {
      debugPrint('⚠️ User data load timeout after ${maxWait.inSeconds}s');
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
    _firebaseUser = null;
    _currentUser = null;
    _isLoading = false;
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
    _fcmService.reset(); // Reset FCM state on logout
    notifyListeners();
  }

  /// Refresh user data from Firestore
  Future<void> refreshUser() async {
    if (_firebaseUser == null) return;

    try {
      final user = await _userRepository.getUser(_firebaseUser!.uid);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error refreshing user: $e');
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    if (_currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Delete user document from Firestore first
      // We do this first because if we delete auth first, we might lose permission to delete firestore data
      await _userRepository.deleteUser(_currentUser!.id);

      // 2. Delete Firebase Auth account
      try {
        await _authRepository.deleteAccount();
      } catch (e) {
        debugPrint('⚠️ Failed to delete auth account (likely requires recent login): $e');
        // Even if auth delete fails, we should clear local state since data is gone
        // proper logout will force user to re-login if they want to recover (though data is gone)
        // ideally we should prompt for re-login BEFORE starting this process, but for now:
        rethrow; 
      }

      // 3. Clear local state (Logout)
      _clearUser();
    } catch (e) {
      debugPrint('❌ Delete account failed: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authStateSubscription?.cancel();
    _userDataSubscription?.cancel();
    super.dispose();
  }
}
