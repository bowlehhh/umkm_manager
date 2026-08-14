import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/email_verification_required_exception.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  bool get hasVerifiedSession {
    final user = currentUser;
    return user != null && user.emailConfirmedAt != null;
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user?.emailConfirmedAt == null) {
        await _client.auth.signOut();
        throw const EmailVerificationRequiredException();
      }
    } on AuthException catch (error) {
      if (error.message.toLowerCase().contains('email not confirmed')) {
        throw const EmailVerificationRequiredException();
      }
      rethrow;
    }
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    // Akun baru selalu kembali ke layar masuk. Jika Confirm email aktif pada
    // Supabase, session memang null sampai pengguna membuka tautan verifikasi.
    // Sign out juga mencegah auto-login jika setting itu keliru dimatikan.
    if (response.session != null) await _client.auth.signOut();
    return false;
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
