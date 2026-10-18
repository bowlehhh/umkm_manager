import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/admin/domain/voucher_form_validator.dart';

void main() {
  group('voucher form validation', () {
    test('accepts a valid admin voucher draft', () {
      expect(VoucherFormValidator.code('promo_2026'), isNull);
      expect(VoucherFormValidator.required('Promo pelanggan', 'Label'), isNull);
      expect(VoucherFormValidator.integer('7', 'Durasi hari'), isNull);
      expect(
        VoucherFormValidator.integer('0', 'Quota AI harian', minimum: 0),
        isNull,
      );
      expect(VoucherFormValidator.integer('1', 'Maksimal redeem'), isNull);
    });

    test('blocks invalid values before the create RPC is sent', () {
      expect(VoucherFormValidator.code('   '), isNotNull);
      expect(VoucherFormValidator.code('bad code'), isNotNull);
      expect(VoucherFormValidator.integer('0', 'Durasi hari'), isNotNull);
      expect(
        VoucherFormValidator.integer('-1', 'Quota AI harian', minimum: 0),
        isNotNull,
      );
      expect(VoucherFormValidator.integer('0', 'Maksimal redeem'), isNotNull);
    });
  });
}
