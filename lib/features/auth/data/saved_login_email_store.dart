import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Email bukan credential rahasia, tetapi tetap disimpan pada secure storage
/// agar hanya mengisi ulang akun terakhir di perangkat ini.
abstract interface class SavedLoginEmailStore {
  Future<String?> read();
  Future<void> save(String email);
}

class SecureSavedLoginEmailStore implements SavedLoginEmailStore {
  SecureSavedLoginEmailStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'last_signed_in_email';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String email) async {
    try {
      await _storage.write(key: _key, value: email.trim().toLowerCase());
    } catch (_) {
      // Kemudahan pengisian email tidak boleh menghalangi login.
    }
  }
}

final savedLoginEmailStoreProvider = Provider<SavedLoginEmailStore>(
  (_) => SecureSavedLoginEmailStore(),
);
