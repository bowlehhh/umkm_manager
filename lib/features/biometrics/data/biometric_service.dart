import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class LocalAuthenticator {
  Future<bool> isDeviceSupported();

  Future<bool> get canCheckBiometrics;

  Future<List<BiometricType>> getAvailableBiometrics();

  Future<bool> authenticate({required String localizedReason});
}

class LocalAuthAuthenticator implements LocalAuthenticator {
  LocalAuthAuthenticator([LocalAuthentication? authentication])
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> get canCheckBiometrics => _authentication.canCheckBiometrics;

  @override
  Future<bool> isDeviceSupported() => _authentication.isDeviceSupported();

  @override
  Future<List<BiometricType>> getAvailableBiometrics() =>
      _authentication.getAvailableBiometrics();

  @override
  Future<bool> authenticate({required String localizedReason}) =>
      _authentication.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
}

abstract interface class BiometricSecureStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

class FlutterSecureBiometricStore implements BiometricSecureStore {
  FlutterSecureBiometricStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

class BiometricAvailability {
  const BiometricAvailability({
    required this.deviceSupported,
    required this.canCheckBiometrics,
    required this.types,
  });

  const BiometricAvailability.unavailable()
    : deviceSupported = false,
      canCheckBiometrics = false,
      types = const [];

  final bool deviceSupported;
  final bool canCheckBiometrics;
  final List<BiometricType> types;

  bool get isAvailable =>
      deviceSupported && canCheckBiometrics && types.isNotEmpty;

  String get actionLabel {
    if (types.contains(BiometricType.fingerprint)) {
      return 'Masuk dengan sidik jari';
    }
    if (types.contains(BiometricType.face)) return 'Masuk dengan wajah';
    return 'Masuk dengan biometrik';
  }
}

enum BiometricAuthenticationResult {
  success,
  cancelled,
  lockedOut,
  failed,
  unavailable,
}

/// Menyimpan hanya flag perangkat dan id akun yang mengaktifkannya. Password,
/// token, serta data biometrik tidak pernah disimpan atau dibaca Flutter.
class BiometricService {
  BiometricService(this._authenticator, this._store);

  static const _enabledAccountKey = 'biometric_enabled_account_id';

  final LocalAuthenticator _authenticator;
  final BiometricSecureStore _store;

  Future<BiometricAvailability> getAvailability() async {
    try {
      final supported = await _authenticator.isDeviceSupported();
      final canCheck = await _authenticator.canCheckBiometrics;
      final types = canCheck
          ? await _authenticator.getAvailableBiometrics()
          : const <BiometricType>[];
      return BiometricAvailability(
        deviceSupported: supported,
        canCheckBiometrics: canCheck,
        types: types,
      );
    } catch (_) {
      return const BiometricAvailability.unavailable();
    }
  }

  Future<bool> isEnabledForAccount(String accountId) async =>
      await _store.read(key: _enabledAccountKey) == accountId;

  Future<void> enableForAccount(String accountId) =>
      _store.write(key: _enabledAccountKey, value: accountId);

  Future<void> disable() => _store.delete(key: _enabledAccountKey);

  Future<BiometricAuthenticationResult> authenticate() async {
    final availability = await getAvailability();
    if (!availability.isAvailable) {
      return BiometricAuthenticationResult.unavailable;
    }
    try {
      final authenticated = await _authenticator.authenticate(
        localizedReason: 'Verifikasi biometrik untuk membuka ikam.',
      );
      return authenticated
          ? BiometricAuthenticationResult.success
          : BiometricAuthenticationResult.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback =>
          BiometricAuthenticationResult.cancelled,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          BiometricAuthenticationResult.unavailable,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          BiometricAuthenticationResult.lockedOut,
        _ => BiometricAuthenticationResult.failed,
      };
    } catch (_) {
      return BiometricAuthenticationResult.failed;
    }
  }
}
