import 'package:supabase_flutter/supabase_flutter.dart';

/// What kind of outcome an auth attempt had.
///
/// The repository reports a kind rather than a sentence because it has no
/// BuildContext and so no locale. The two messages this app authors are
/// translated at the call site; [serverMessage] is passed through untouched
/// because it comes from Supabase, which answers in English whatever the
/// phone's language is.
enum AuthOutcome { success, needsEmailConfirmation, offline, rejected }

class AuthResult {
  final AuthOutcome outcome;

  /// Supabase's own wording, when the server is what refused. Not localised.
  final String? serverMessage;

  const AuthResult._(this.outcome, [this.serverMessage]);

  const AuthResult.success() : this._(AuthOutcome.success);

  /// The account exists but cannot sign in until the email is confirmed.
  const AuthResult.confirmEmail() : this._(AuthOutcome.needsEmailConfirmation);

  /// Never reached the server at all.
  const AuthResult.offline() : this._(AuthOutcome.offline);

  /// The server answered, and said no.
  const AuthResult.rejected(String message)
    : this._(AuthOutcome.rejected, message);

  bool get success =>
      outcome == AuthOutcome.success ||
      outcome == AuthOutcome.needsEmailConfirmation;

  bool get needsEmailConfirmation =>
      outcome == AuthOutcome.needsEmailConfirmation;
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
      return AuthResult.rejected(error.message);
    } catch (_) {
      return const AuthResult.offline();
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
        return const AuthResult.confirmEmail();
      }
      return const AuthResult.success();
    } on AuthException catch (error) {
      return AuthResult.rejected(error.message);
    } catch (_) {
      return const AuthResult.offline();
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Deletes the signed-in user's account on the server, with everything
  /// stored under it there, then ends the session on this phone. False when
  /// the server could not be reached or refused; nothing changes then.
  Future<bool> deleteAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      final data = response.data;
      if (data is! Map || data['deleted'] != true) return false;
    } catch (_) {
      return false;
    }
    // Local only: the user no longer exists, so a server-side sign-out
    // would be refused.
    await _client.auth.signOut(scope: SignOutScope.local);
    return true;
  }
}
