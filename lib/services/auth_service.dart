import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get the current authenticated user (if any).
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream to listen for auth state changes (Sign in, Sign out, etc.).
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Signs in a user with email and password.
  /// Returns null if successful, or an error message string if it fails.
  Future<String?> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null; // Success
    } on AuthException catch (e) {
      return e.message; // Return Supabase specific error
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Registers a new user with email and password.
  /// Returns null if successful, or an error message string if it fails.
  Future<String?> signUp({required String email, required String password}) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return null; // Success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Sends a password reset link to the given email.
  /// Returns null if successful, or an error message string if it fails.
  Future<String?> resetPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
