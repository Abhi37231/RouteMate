import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Authentication service for Firebase Auth
/// FIXED: Proper Google Sign-In flow compatible with firebase_auth ^5.x
class AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  late final GoogleSignIn _googleSignIn;

  // Dev mode flag to bypass reCAPTCHA issues
  static const bool _devMode = true;

  AuthService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance {
    // FIXED: Removed invalid serverClientId parameter.
    // GoogleSignIn constructor only accepts: hostedDomain, scopes, signInOption, clientId.
    // The Web Client ID is automatically read from google-services.json (R.string.default_web_client_id).
    _googleSignIn = googleSignIn ??
        GoogleSignIn(
          scopes: ['email'],
        );
  }

  /// Get current user
  firebase_auth.User? get currentUser => _firebaseAuth.currentUser;

  /// Get auth state changes stream
  Stream<firebase_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  /// Sign in with email and password
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      // If reCAPTCHA network error or general network error in dev mode, retry once
      if (_devMode &&
          (e.code == 'network-request-failed' ||
              e.message?.contains('network') == true)) {
        await Future.delayed(const Duration(seconds: 2));
        return await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      rethrow;
    }
  }

  /// Create user with email and password
  Future<firebase_auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      // If reCAPTCHA network error in dev mode, retry once
      if (_devMode &&
          (e.code == 'network-request-failed' ||
              e.message?.contains('network') == true)) {
        await Future.delayed(const Duration(seconds: 2));
        return await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      rethrow;
    }
  }

  /// Sign in with Google — Rewritten for firebase_auth ^5.x null-safe Pigeon API
  ///
  /// Root cause of original crash:
  ///   firebase_auth 4.16.x had a Pigeon deserialization bug on Android.
  ///   google_sign_in 6.2.1 sent List<Object?> over the platform channel, but
  ///   firebase_auth expected PigeonUserDetails, causing a type-cast crash.
  ///
  /// Fixes applied:
  /// 1. Upgraded firebase_auth to ^5.x (includes corrected Pigeon bindings).
  /// 2. Removed invalid serverClientId parameter from GoogleSignIn constructor.
  /// 3. Simplified to the canonical signIn → authenticate → credential flow.
  Future<firebase_auth.UserCredential> signInWithGoogle() async {
    try {
      // Start interactive Google sign-in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in was cancelled by user');
      }

      // Retrieve OAuth 2.0 tokens from the Google account
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      // On Android, both tokens should be present. If either is missing,
      // something is wrong with the Google OAuth configuration.
      if (idToken == null || accessToken == null) {
        throw Exception(
          'Missing Google authentication tokens. '
          'Ensure SHA-1 fingerprint and Web Client ID are configured in Firebase Console.',
        );
      }

      // Create Firebase Auth credential using both tokens
      final firebase_auth.AuthCredential credential =
          firebase_auth.GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      // Sign in to Firebase with the Google credential
      return await _firebaseAuth.signInWithCredential(credential);
    } on PlatformException catch (e) {
      // Preserve PlatformException codes (e.g., sign_in_failed, network_error)
      // so the UI layer can display specific troubleshooting messages.
      throw Exception(
          'Google sign-in platform error: ${e.code} — ${e.message}');
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  /// Sign in anonymously (for testing)
  Future<firebase_auth.UserCredential> signInAnonymously() async {
    return await _firebaseAuth.signInAnonymously();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }

  /// Delete user account
  Future<void> deleteUser() async {
    await _firebaseAuth.currentUser?.delete();
  }

  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    await _firebaseAuth.currentUser?.updateProfile(
      displayName: displayName,
      photoURL: photoURL,
    );
  }

  /// Update user email
  Future<void> updateEmail(String email) async {
    await _firebaseAuth.currentUser?.verifyBeforeUpdateEmail(email);
  }

  /// Reload user
  Future<void> reloadUser() async {
    await _firebaseAuth.currentUser?.reload();
  }
}
