import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umkm_manager/features/admin/data/admin_repository.dart';

void main() {
  PostgrestException error(String code) =>
      PostgrestException(message: 'internal database detail', code: code);

  test('maps voucher create errors to safe admin messages', () {
    expect(
      AdminVoucherErrorMapper.create(error('PGRST202')).message,
      'Layanan voucher belum tersedia.',
    );
    expect(
      AdminVoucherErrorMapper.create(error('42501')).message,
      'Anda tidak memiliki izin membuat voucher.',
    );
    expect(
      AdminVoucherErrorMapper.create(error('23505')).message,
      'Kode voucher sudah digunakan.',
    );
    expect(
      AdminVoucherErrorMapper.create(error('22023')).message,
      contains('Data voucher tidak valid'),
    );
    expect(
      AdminVoucherErrorMapper.create(error('XX000')).message,
      'Terjadi gangguan pada server. Silakan coba lagi.',
    );
  });

  test('create voucher payload uses the exact eight production parameters', () {
    final payload = AdminVoucherCreatePayload(
      code: ' promo-2026 ',
      label: ' Paket promo ',
      durationDays: 7,
      aiQuota: null,
      maxRedemptions: 10,
      startsAt: null,
      expiresAt: DateTime.utc(2026, 12, 31),
      planKey: AdminVoucherCreatePayload.defaultPlanKey,
    ).toRpcParams();

    expect(
      payload.keys,
      orderedEquals(const [
        'p_code',
        'p_label',
        'p_duration_days',
        'p_ai_quota',
        'p_max_redemptions',
        'p_starts_at',
        'p_expires_at',
        'p_plan_key',
      ]),
    );
    expect(payload['p_code'], 'PROMO-2026');
    expect(payload['p_label'], 'Paket promo');
    expect(payload['p_duration_days'], isA<int>());
    expect(payload['p_ai_quota'], isNull);
    expect(payload['p_max_redemptions'], isA<int>());
    expect(payload['p_starts_at'], isNull);
    expect(payload['p_expires_at'], isA<String>());
    expect(payload['p_plan_key'], 'voucher');
  });

  test(
    'development diagnostics redact voucher and credential-shaped values',
    () {
      final diagnostic = AdminVoucherDiagnostic.safeText(
        'code=PROMO-2026 authorization=Bearer abc123 api_key=secret',
        voucherCode: 'PROMO-2026',
      );

      expect(diagnostic, isNot(contains('PROMO-2026')));
      expect(diagnostic, isNot(contains('abc123')));
      expect(diagnostic, isNot(contains('secret')));
    },
  );
}
