import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Stream of Firebase auth state changes
  Stream<firebase_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  /// Get current Firebase user
  firebase_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Sign in with Google
  Future<firebase_auth.UserCredential> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      return await _firebaseAuth.signInWithCredential(credential);
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
