import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_mapper.dart';
import '../../data/auth_repository.dart';
import '../../data/saved_login_email_store.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> signIn({required String email, required String password}) {
    return _run(() async {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email.trim(), password: password);
      await ref.read(savedLoginEmailStoreProvider).save(email);
    });
  }

  Future<RegisterResult> signUp({
    required String fullName,
    required String email,
    String? phoneE164,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final signedIn = await ref
          .read(authRepositoryProvider)
          .signUp(
            fullName: fullName.trim(),
            email: email.trim(),
            phoneE164: phoneE164,
            password: password,
          );
      await ref.read(savedLoginEmailStoreProvider).save(email);
      state = const AsyncData(null);
      return RegisterResult(signedIn: signedIn);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return RegisterResult(error: AppErrorMapper.message(error));
    }
  }

  Future<String?> sendPasswordReset(String email) {
    return _run(
      () => ref.read(authRepositoryProvider).sendPasswordReset(email.trim()),
    );
  }

  Future<String?> sendPhoneOtp(
    String phone, {
    required bool shouldCreateUser,
  }) => _run(
    () => ref
        .read(authRepositoryProvider)
        .sendPhoneOtp(phone, shouldCreateUser: shouldCreateUser),
  );

  Future<String?> verifyPhone({
    required String phone,
    required String token,
    String? contactEmail,
  }) => _run(
    () => ref
        .read(authRepositoryProvider)
        .verifyPhone(phone: phone, token: token, contactEmail: contactEmail),
  );

  Future<String?> updatePassword(String password) =>
      _run(() => ref.read(authRepositoryProvider).updatePassword(password));

  Future<String?> signOut() {
    return _run(() => ref.read(authRepositoryProvider).signOut());
  }

  Future<String?> _run(Future<void> Function() operation) async {
    state = const AsyncLoading();
    try {
      await operation();
      state = const AsyncData(null);
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AppErrorMapper.message(error);
    }
  }
}

class RegisterResult {
  const RegisterResult({this.signedIn = false, this.error});

  final bool signedIn;
  final String? error;

  bool get isSuccess => error == null;
}
