import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService extends SupabaseService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Gets the current session if it exists.
  Session? get currentSession => client.auth.currentSession;

  /// Gets the current user if logged in.
  User? get currentUser => client.auth.currentUser;

  /// Signs up a new user with email and password.
  Future<AuthResponse> signUp(String email, String password) async {
    log('Attempting Sign Up: $email');
    if (!await ensureConnection()) {
      throw Exception('No internet connection');
    }
    
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      log('Sign Up Success: ${response.user?.id}');
      return response;
    } catch (e) {
      log('Sign Up Error: $e');
      rethrow;
    }
  }

  /// Signs in an existing user.
  Future<AuthResponse> signIn(String email, String password) async {
    log('Attempting Sign In: $email');
    if (!await ensureConnection()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      log('Sign In Success: ${response.user?.id}');
      return response;
    } catch (e) {
      log('Sign In Error: $e');
      rethrow;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    log('Attempting Sign Out');
    try {
      await client.auth.signOut();
      log('Sign Out Success');
    } catch (e) {
      log('Sign Out Error: $e');
      rethrow;
    }
  }
}
