import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umkm_manager/core/utils/app_error_mapper.dart';
import 'package:umkm_manager/features/auth/domain/phone_confirmation_required_exception.dart';

void main() {
  test('SMS provider failure has an actionable message', () {
    expect(
      AppErrorMapper.message(
        const AuthException(
          'Error sending confirmation SMS',
          statusCode: '500',
        ),
      ),
      contains('Kode SMS belum dapat dikirim'),
    );
  });

  test('Supabase phone provider and SMS codes are actionable', () {
    expect(
      AppErrorMapper.message(
        const AuthException('', code: 'phone_provider_disabled'),
      ),
      contains('belum diaktifkan'),
    );
    expect(
      AppErrorMapper.message(const AuthException('', code: 'sms_send_failed')),
      contains('Kode SMS'),
    );
  });

  test('network failure is not reduced to a generic error', () {
    expect(
      AppErrorMapper.message(AuthRetryableFetchException()),
      contains('koneksi'),
    );
  });

  test('missing confirm-phone configuration is actionable', () {
    expect(
      AppErrorMapper.message(const PhoneConfirmationRequiredException()),
      contains('Confirm phone'),
    );
  });
}
