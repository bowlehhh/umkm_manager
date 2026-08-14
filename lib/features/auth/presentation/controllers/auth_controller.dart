import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_mapper.dart';
import '../../data/auth_repository.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> signIn({required String email, required String password}) {
    return _run(
      () => ref
          .read(authRepositoryProvider)
          .signIn(email: email.trim(), password: password),
    );
  }

  Future<RegisterResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final signedIn = await ref
          .read(authRepositoryProvider)
          .signUp(
            fullName: fullName.trim(),
            email: email.trim(),
            password: password,
          );
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
