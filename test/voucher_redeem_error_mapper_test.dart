import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umkm_manager/features/entitlements/data/voucher_repository.dart';

void main() {
  PostgrestException error(String message, {String code = '22023'}) =>
      PostgrestException(message: message, code: code);

  test('voucher invalid tetap menampilkan pesan aman', () {
    expect(
      VoucherRedeemErrorMapper.fromPostgrest(error('Voucher tidak valid')),
      'Kode voucher tidak valid.',
    );
  });

  test(
    'voucher expired tetap menampilkan halaman aktivasi dengan pesan aman',
    () {
      expect(
        VoucherRedeemErrorMapper.fromPostgrest(error('Voucher telah berakhir')),
        'Voucher sudah kedaluwarsa.',
      );
    },
  );

  test(
    'voucher exhausted tetap menampilkan halaman aktivasi dengan pesan aman',
    () {
      expect(
        VoucherRedeemErrorMapper.fromPostgrest(
          error('Voucher telah habis digunakan'),
        ),
        'Voucher sudah mencapai batas penggunaan.',
      );
    },
  );

  test('redeem berulang tidak membocorkan pesan database', () {
    expect(
      VoucherRedeemErrorMapper.fromPostgrest(
        error('Voucher sudah pernah digunakan akun ini', code: '23505'),
      ),
      'Voucher ini sudah pernah digunakan akun Anda.',
    );
  });
}
