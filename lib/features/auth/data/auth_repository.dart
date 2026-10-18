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
        password: password,
        email: email.trim().toLowerCase(),
      );
      final user = response.user;
      if (user != null && user.emailConfirmedAt == null) {
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
    String? phoneE164,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'full_name': fullName,
        // Contact email is profile data. It is not a second Auth identity.
        'contact_email': email.trim().toLowerCase(),
        'phone_e164': ?phoneE164,
      },
    );
    return response.session != null;
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<void> sendPhoneOtp(String phone, {required bool shouldCreateUser}) =>
      _client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: shouldCreateUser,
        channel: OtpChannel.sms,
      );

  Future<void> verifyPhone({
    required String phone,
    required String token,
    String? contactEmail,
  }) async {
    await _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
    final user = currentUser;
    if (user == null) throw StateError('Verifikasi belum berhasil. Coba lagi.');
    await _client.from('profiles').upsert({
      'id': user.id,
      'phone_e164': phone,
      'phone_verified': true,
      if (contactEmail != null && contactEmail.isNotEmpty)
        'contact_email': contactEmail,
    });
  }

  Future<void> updatePassword(String password) =>
      _client.auth.updateUser(UserAttributes(password: password));

  Future<void> signOut() => _client.auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
