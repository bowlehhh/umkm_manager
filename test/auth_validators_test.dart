import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/auth/presentation/views/auth_validators.dart';

void main() {
  test('optional phone is accepted when empty', () {
    expect(validateOptionalIndonesianPhone(''), isNull);
  });

  test('optional phone is normalized-compatible when supplied', () {
    expect(validateOptionalIndonesianPhone('081234567890'), isNull);
    expect(validateOptionalIndonesianPhone('81234567890'), isNull);
  });

  test('invalid optional phone is rejected only when supplied', () {
    expect(validateOptionalIndonesianPhone('071234'), 'Nomor HP belum benar.');
  });

  test('email remains required for beta authentication', () {
    expect(validateEmail(''), 'Email wajib diisi.');
    expect(validateEmail('bukan-email'), 'Masukkan alamat email yang valid.');
    expect(validateEmail('usaha@example.com'), isNull);
  });
}
