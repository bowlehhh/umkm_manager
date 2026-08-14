import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/biometric_service.dart';

class BiometricSessionState {
  const BiometricSessionState({
    required this.isLoading,
    required this.availability,
    required this.isEnabled,
    required this.isUnlocked,
    this.shouldOfferEnrollment = false,
    this.message,
  });

  const BiometricSessionState.loading()
    : isLoading = true,
      availability = const BiometricAvailability.unavailable(),
      isEnabled = false,
      isUnlocked = false,
      shouldOfferEnrollment = false,
      message = null;

  final bool isLoading;
  final BiometricAvailability availability;
  final bool isEnabled;
  final bool isUnlocked;
  final bool shouldOfferEnrollment;
  final String? message;

  bool get requiresUnlock => isEnabled && !isUnlocked;

  BiometricSessionState copyWith({
    bool? isLoading,
    BiometricAvailability? availability,
    bool? isEnabled,
    bool? isUnlocked,
    bool? shouldOfferEnrollment,
    String? message,
    bool clearMessage = false,
  }) => BiometricSessionState(
    isLoading: isLoading ?? this.isLoading,
    availability: availability ?? this.availability,
    isEnabled: isEnabled ?? this.isEnabled,
    isUnlocked: isUnlocked ?? this.isUnlocked,
    shouldOfferEnrollment: shouldOfferEnrollment ?? this.shouldOfferEnrollment,
    message: clearMessage ? null : message ?? this.message,
  );
}

class BiometricSessionNotifier extends ChangeNotifier {
  BiometricSessionNotifier(this._authRepository, this._service) {
    _subscription = _authRepository.authStateChanges.listen(_onAuthChanged);
    unawaited(_restorePersistedSession());
  }

  final AuthRepository _authRepository;
  final BiometricService _service;
  late final StreamSubscription<AuthState> _subscription;
  BiometricSessionState _state = const BiometricSessionState.loading();

  BiometricSessionState get state => _state;

  Future<void> _restorePersistedSession() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _setReady();
      return;
    }
    await _loadForAccount(user.id, unlocked: false, offerEnrollment: false);
  }

  Future<void> _onAuthChanged(AuthState event) async {
    switch (event.event) {
      case AuthChangeEvent.signedOut:
        await _service.disable();
        _setReady();
      case AuthChangeEvent.signedIn:
        final user = event.session?.user ?? _authRepository.currentUser;
        if (user == null) {
          _setReady();
        } else {
          await _loadForAccount(user.id, unlocked: true, offerEnrollment: true);
        }
      case AuthChangeEvent.initialSession:
        final user = event.session?.user ?? _authRepository.currentUser;
        if (user == null) {
          _setReady();
        } else {
          await _loadForAccount(
            user.id,
            unlocked: false,
            offerEnrollment: false,
          );
        }
      default:
        break;
    }
  }

  Future<void> _loadForAccount(
    String accountId, {
    required bool unlocked,
    required bool offerEnrollment,
  }) async {
    _state = _state.copyWith(isLoading: true, clearMessage: true);
    notifyListeners();
    final availability = await _service.getAvailability();
    final enabled =
        availability.isAvailable &&
        await _service.isEnabledForAccount(accountId);
    _state = BiometricSessionState(
      isLoading: false,
      availability: availability,
      isEnabled: enabled,
      isUnlocked: unlocked || !enabled,
      shouldOfferEnrollment:
          offerEnrollment && availability.isAvailable && !enabled,
    );
    notifyListeners();
  }

  void _setReady() {
    _state = const BiometricSessionState(
      isLoading: false,
      availability: BiometricAvailability.unavailable(),
      isEnabled: false,
      isUnlocked: false,
    );
    notifyListeners();
  }

  /// Verifikasi native wajib berhasil sebelum preference biometrik disimpan.
  /// Flutter hanya menerima hasil berhasil/gagal, tidak pernah data biometrik.
  Future<BiometricAuthenticationResult> enableForCurrentAccount() async {
    final user = _authRepository.currentUser;
    if (user == null || !_state.availability.isAvailable) {
      _state = _state.copyWith(
        message: 'Biometrik belum tersedia pada perangkat ini.',
      );
      notifyListeners();
      return BiometricAuthenticationResult.unavailable;
    }
    _state = _state.copyWith(isLoading: true, clearMessage: true);
    notifyListeners();
    final result = await _service.authenticate();
    if (result == BiometricAuthenticationResult.success) {
      await _service.enableForAccount(user.id);
    }
    _state = _state.copyWith(
      isLoading: false,
      isEnabled: result == BiometricAuthenticationResult.success,
      isUnlocked: true,
      shouldOfferEnrollment: false,
      message: switch (result) {
        BiometricAuthenticationResult.success => null,
        BiometricAuthenticationResult.cancelled =>
          'Verifikasi dibatalkan. Login biometrik belum diaktifkan.',
        BiometricAuthenticationResult.unavailable =>
          'Belum ada biometrik yang terdaftar pada perangkat ini.',
        BiometricAuthenticationResult.failed =>
          'Verifikasi belum berhasil. Login biometrik belum diaktifkan.',
      },
      clearMessage: result == BiometricAuthenticationResult.success,
    );
    notifyListeners();
    return result;
  }

  Future<void> disable() async {
    await _service.disable();
    _state = _state.copyWith(
      isEnabled: false,
      isUnlocked: true,
      shouldOfferEnrollment: false,
      clearMessage: true,
    );
    notifyListeners();
  }

  /// Mengunci tampilan tanpa menghapus sesi Supabase. Router akan membawa
  /// pengguna ke layar biometrik selama fitur ini sudah aktif pada akun ini.
  void lock() {
    if (!_state.isEnabled) return;
    _state = _state.copyWith(isUnlocked: false, clearMessage: true);
    notifyListeners();
  }

  void dismissEnrollmentPrompt() {
    if (!_state.shouldOfferEnrollment) return;
    _state = _state.copyWith(shouldOfferEnrollment: false);
    notifyListeners();
  }

  Future<BiometricAuthenticationResult> unlock() async {
    if (!_state.requiresUnlock) return BiometricAuthenticationResult.success;
    final result = await _service.authenticate();
    final message = switch (result) {
      BiometricAuthenticationResult.success => null,
      BiometricAuthenticationResult.cancelled =>
        'Autentikasi biometrik dibatalkan.',
      BiometricAuthenticationResult.unavailable =>
        'Biometrik tidak tersedia pada perangkat ini.',
      BiometricAuthenticationResult.failed =>
        'Autentikasi biometrik belum berhasil. Coba lagi atau masuk dengan email.',
    };
    _state = _state.copyWith(
      isUnlocked: result == BiometricAuthenticationResult.success,
      message: message,
      clearMessage: result == BiometricAuthenticationResult.success,
    );
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService(
    LocalAuthAuthenticator(),
    FlutterSecureBiometricStore(),
  );
});

final biometricSessionNotifierProvider = Provider<BiometricSessionNotifier>((
  ref,
) {
  final notifier = BiometricSessionNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(biometricServiceProvider),
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});
