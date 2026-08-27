import 'package:supabase_flutter/supabase_flutter.dart';

/// Outcome of a sign-in or sign-up attempt, in terms the UI can show.
class AuthResult {
  final bool success;

  /// Error to show, or the note explaining what happens next.
  final String? message;

  /// The account exists but cannot sign in until the email is confirmed.
  final bool needsEmailConfirmation;

  const AuthResult._({
    required this.success,
    this.message,
    this.needsEmailConfirmation = false,
  });

  const AuthResult.success() : this._(success: true);

  const AuthResult.failure(String message)
    : this._(success: false, message: message);

  const AuthResult.confirmEmail(String message)
    : this._(success: true, message: message, needsEmailConfirmation: true);
}

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Emits on sign in, sign out and token refresh, so the router can react.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Restored from local storage at startup, so a returning user is not
  /// pushed back to the login screen just because they are offline.
  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return const AuthResult.success();
    } on AuthException catch (error) {
      return AuthResult.failure(error.message);
    } catch (_) {
      return const AuthResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      // With email confirmation enabled, Supabase creates the user but
      // withholds a session until the link is clicked.
      if (response.session == null) {
        return const AuthResult.confirmEmail(
          'Account created. Check your inbox to confirm your email, then '
          'sign in.',
        );
      }
      return const AuthResult.success();
    } on AuthException catch (error) {
      return AuthResult.failure(error.message);
    } catch (_) {
      return const AuthResult.failure(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<void> signOut() => _client.auth.signOut();
}
