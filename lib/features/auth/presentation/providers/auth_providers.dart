import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/auth_service.dart';

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Connectivity check provider
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

/// Current user provider
final currentUserProvider = StreamProvider<firebase_auth.User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Auth error provider
final authErrorProvider = StateProvider<String?>((ref) => null);

/// Auth state provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier(ref.watch(authServiceProvider), ref);
});

/// Auth state
enum AuthState { initial, loading, authenticated, unauthenticated, error }

/// Auth state notifier
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final StateNotifierProviderRef ref;

  AuthStateNotifier(this._authService, this.ref) : super(AuthState.initial);

  /// Check network connectivity
  Future<bool> _checkNetwork() async {
    try {
      final connectivity = ref.read(connectivityProvider);
      // ignore: unnecessary_cast
      final result = await connectivity.checkConnectivity() as dynamic;

      // Handle both single result (version 5.x) and list (version 6.x)
      final bool hasNoNetwork;
      if (result is List) {
        hasNoNetwork = result.isEmpty ||
            (result.length == 1 && result.contains(ConnectivityResult.none));
      } else {
        hasNoNetwork = result == ConnectivityResult.none;
      }

      if (hasNoNetwork) {
        ref.read(authErrorProvider.notifier).state =
            'No internet connection. Please check your network and try again.';
        return false;
      }
      return true;
    } catch (e) {
      // If connectivity check fails, assume we have network and let the service call fail if needed
      return true;
    }
  }

  /// Retry wrapper with network check
  Future<bool> _tryAuth(Future<bool> Function() authFunc) async {
    // Check network first
    if (!await _checkNetwork()) {
      state = AuthState.error;
      return false;
    }

    state = AuthState.loading;
    try {
      final success = await authFunc();
      return success;
    } catch (e) {
      final errorMsg = _getErrorMessage(e);
      ref.read(authErrorProvider.notifier).state = errorMsg;
      state = AuthState.error;
      return false;
    }
  }

  /// Get error message
  String? _getErrorMessage(dynamic error) {
    // Handle Firebase Auth specific errors
    if (error is firebase_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'weak-password':
          return 'The password provided is too weak. Please use at least 6 characters.';
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'The password is incorrect.';
        case 'too-many-requests':
          return 'Too many login attempts. Please try again later.';
        case 'operation-not-allowed':
          return 'Email/password sign up is not enabled in Firebase Console.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        case 'invalid-credential':
          return 'Invalid credentials. Please check your email and password.';
        default:
          return error.message ?? 'Authentication failed (${error.code}).';
      }
    }

    // Handle Google Sign-In common errors (PlatformException)
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('sign_in_failed') || errorStr.contains('api_exception')) {
      if (errorStr.contains('code 10')) {
        return 'Google Sign-In Error: Developer error (code 10). This usually means SHA-1 fingerprint is missing in Firebase Console or package name mismatch.';
      } else if (errorStr.contains('code 12500')) {
        return 'Google Sign-In Error: Sign-in failed (code 12500). Please ensure a support email is set in Firebase Project Settings.';
      } else if (errorStr.contains('code 7')) {
        return 'Google Sign-In Error: Network error. Please check your internet connection.';
      }
      return 'Google Sign-In failed. Please ensure you have added your SHA-1 fingerprint to the Firebase Console.';
    }

    if (errorStr.contains('network error') || errorStr.contains('failed host lookup')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    if (errorStr.contains('cancelled')) {
      return 'Sign-in was cancelled.';
    }

    return 'An unexpected error occurred: ${error.toString()}';
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    // Check network first with retry logic
    if (!await _checkNetwork()) {
      state = AuthState.error;
      return false;
    }

    // Add retry for networkerrors
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        state = AuthState.loading;
        await _authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        ref.read(authErrorProvider.notifier).state = null;
        state = AuthState.authenticated;
        return true;
      } catch (e) {
        // If it's a network error and we have retries left, try again
        if (e is firebase_auth.FirebaseAuthException &&
            e.code == 'network-request-failed' &&
            attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
        final errorMsg = _getErrorMessage(e);
        ref.read(authErrorProvider.notifier).state = errorMsg;
        state = AuthState.error;
        return false;
      }
    }
    return false;
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail(String email, String password) async {
    // Check network first
    if (!await _checkNetwork()) {
      state = AuthState.error;
      return false;
    }

    // Add retry for network errors
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        state = AuthState.loading;
        // Validate password strength
        if (password.length < 6) {
          throw firebase_auth.FirebaseAuthException(
            code: 'weak-password',
            message:
                'The password provided is too weak. Please use at least 6 characters.',
          );
        }

        await _authService.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        ref.read(authErrorProvider.notifier).state = null;
        state = AuthState.authenticated;
        return true;
      } catch (e) {
        // If it's a network error and we have retries left, try again
        if (e is firebase_auth.FirebaseAuthException &&
            e.code == 'network-request-failed' &&
            attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
        final errorMsg = _getErrorMessage(e);
        ref.read(authErrorProvider.notifier).state = errorMsg;
        state = AuthState.error;
        return false;
      }
    }
    return false;
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    state = AuthState.loading;
    try {
      await _authService.signInWithGoogle();
      ref.read(authErrorProvider.notifier).state = null;
      state = AuthState.authenticated;
      return true;
    } catch (e) {
      final errorMsg = _getErrorMessage(e);
      ref.read(authErrorProvider.notifier).state = errorMsg;
      state = AuthState.error;
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    ref.read(authErrorProvider.notifier).state = null;
    state = AuthState.unauthenticated;
  }

  /// Update user profile
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    state = AuthState.loading;
    try {
      await _authService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );
      // Reload user to get updated data
      await _authService.reloadUser();
      ref.read(authErrorProvider.notifier).state = null;
      state = AuthState.authenticated;
      return true;
    } catch (e) {
      final errorMsg = _getErrorMessage(e);
      ref.read(authErrorProvider.notifier).state = errorMsg;
      state = AuthState.error;
      return false;
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      ref.read(authErrorProvider.notifier).state = null;
      return true;
    } catch (e) {
      final errorMsg = _getErrorMessage(e);
      ref.read(authErrorProvider.notifier).state = errorMsg;
      return false;
    }
  }
}
