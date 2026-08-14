import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:umkm_manager/features/biometrics/data/biometric_service.dart';

void main() {
  test(
    'biometrik hanya dapat dipakai bila hardware dan enrollment tersedia',
    () async {
      final service = BiometricService(
        _FakeAuthenticator(supported: true, canCheck: true),
        _MemoryStore(),
      );

      final availability = await service.getAvailability();

      expect(availability.isAvailable, isTrue);
      expect(availability.actionLabel, 'Masuk dengan sidik jari');
    },
  );

  test(
    'status biometrik hanya berlaku untuk akun yang mengaktifkannya',
    () async {
      final store = _MemoryStore();
      final service = BiometricService(_FakeAuthenticator(), store);

      await service.enableForAccount('akun-a');

      expect(await service.isEnabledForAccount('akun-a'), isTrue);
      expect(await service.isEnabledForAccount('akun-b'), isFalse);
      await service.disable();
      expect(await service.isEnabledForAccount('akun-a'), isFalse);
    },
  );

  test('hasil autentikasi membedakan berhasil, batal, dan gagal', () async {
    final successful = BiometricService(
      _FakeAuthenticator(result: true),
      _MemoryStore(),
    );
    final cancelled = BiometricService(
      _FakeAuthenticator(
        exception: const LocalAuthException(
          code: LocalAuthExceptionCode.userCanceled,
        ),
      ),
      _MemoryStore(),
    );
    final failed = BiometricService(
      _FakeAuthenticator(result: false),
      _MemoryStore(),
    );

    expect(
      await successful.authenticate(),
      BiometricAuthenticationResult.success,
    );
    expect(
      await cancelled.authenticate(),
      BiometricAuthenticationResult.cancelled,
    );
    expect(await failed.authenticate(), BiometricAuthenticationResult.failed);
  });

  test('device tanpa biometrik tidak memunculkan autentikasi', () async {
    final service = BiometricService(
      _FakeAuthenticator(supported: false, canCheck: false, types: const []),
      _MemoryStore(),
    );

    expect(
      await service.authenticate(),
      BiometricAuthenticationResult.unavailable,
    );
  });
}

class _FakeAuthenticator implements LocalAuthenticator {
  _FakeAuthenticator({
    this.supported = true,
    this.canCheck = true,
    this.types = const [BiometricType.fingerprint],
    this.result = true,
    this.exception,
  });

  final bool supported;
  final bool canCheck;
  final List<BiometricType> types;
  final bool result;
  final Object? exception;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    if (exception != null) throw exception!;
    return result;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => types;

  @override
  Future<bool> isDeviceSupported() async => supported;
}

class _MemoryStore implements BiometricSecureStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}
