import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/core/utils/indonesian_phone.dart';

void main() {
  group('normalizeIndonesianPhone', () {
    test('normalizes 08 to E.164', () {
      expect(normalizeIndonesianPhone('081234567890'), '+6281234567890');
    });

    test('normalizes number without leading zero', () {
      expect(normalizeIndonesianPhone('81234567890'), '+6281234567890');
    });

    test('keeps E.164 phone number', () {
      expect(normalizeIndonesianPhone('+6281234567890'), '+6281234567890');
    });

    test('rejects invalid numbers', () {
      expect(normalizeIndonesianPhone('071234'), isNull);
      expect(normalizeIndonesianPhone('+60123456789'), isNull);
    });
  });
}
