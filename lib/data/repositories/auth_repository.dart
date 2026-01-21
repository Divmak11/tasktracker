import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import '../../core/constants/env_config.dart';

/// Result of Google sign-in containing Firebase credential and optional serverAuthCode
/// for calendar token exchange
typedef GoogleSignInResult = ({
  firebase_auth.UserCredential credential,
  String? serverAuthCode,
});

class AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
       // Include calendar scopes and serverClientId for upfront consent
       // This enables token exchange during sign-in flow
       _googleSignIn = googleSignIn ?? GoogleSignIn(
         scopes: ['email', calendar.CalendarApi.calendarEventsScope],
         serverClientId: EnvConfig.googleWebClientId,
       );

  /// Stream of Firebase auth state changes
  Stream<firebase_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  /// Get current Firebase user
  /// Check if user is signed in
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Get current Firebase Auth user (supports ALL auth methods)
  /// Used by AuthProvider to check for existing sessions on app restart
  firebase_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Sign in with Google (includes calendar consent for seamless toggle experience)
  /// Returns both Firebase credential and serverAuthCode for calendar token exchange
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow (now includes calendar scope)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Capture serverAuthCode for calendar token exchange
      final serverAuthCode = googleUser.serverAuthCode;

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      return (credential: userCredential, serverAuthCode: serverAuthCode);
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }


  /// Sign in with Apple (iOS/macOS only)
  Future<firebase_auth.UserCredential> signInWithApple() async {
    try {
      final appleProvider = firebase_auth.AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      return await _firebaseAuth.signInWithProvider(appleProvider);
    } catch (e) {
      throw Exception('Apple Sign-In failed: $e');
    }
  }

  /// Create account with Email and Password
  Future<firebase_auth.UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Account creation failed: $e');
    }
  }

  /// Sign in with Email and Password
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Email Sign-In failed: $e');
    }
  }

  Future<firebase_auth.UserCredential?> signInWithGoogleSilently() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signInSilently(suppressErrors: true);

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } catch (_) {
      return null;
    }
  }

  /// Sign out from Google Sign-In only (keeps Firebase session)
  /// Used to force account picker on next Google Sign-In attempt
  Future<void> signOutGoogleOnly() async {
    await _googleSignIn.signOut();
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  /// Delete current user account
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
