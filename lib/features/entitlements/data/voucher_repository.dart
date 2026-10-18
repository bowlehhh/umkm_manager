import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class VoucherRepository {
  const VoucherRepository(this._client);

  final SupabaseClient _client;

  Future<String?> validate(String code) async {
    final result = await _client.rpc(
      'validate_voucher_code',
      params: {'p_code': code.trim()},
    );
    final rows = result is List ? result : const [];
    if (rows.isEmpty || rows.first is! Map) return 'Voucher tidak valid.';
    final row = Map<String, dynamic>.from(rows.first as Map);
    if (row['valid'] == true) return null;
    return switch (row['reason']) {
      'inactive' => 'Voucher tidak aktif.',
      'not_started' => 'Voucher belum dapat digunakan.',
      'expired' => 'Voucher telah berakhir.',
      'exhausted' => 'Voucher telah habis digunakan.',
      _ => 'Voucher tidak valid.',
    };
  }

  Future<String?> redeem(String code) async {
    try {
      try {
        final invitation = await _client.rpc(
          'redeem_invitation',
          params: {'p_token': code.trim().toUpperCase()},
        );
        final rows = invitation is List ? invitation : const [];
        final row = rows.isNotEmpty && rows.first is Map
            ? Map<String, dynamic>.from(rows.first as Map)
            : const <String, dynamic>{};
        if (row['purpose'] == 'RATE_LIMITED') {
          return 'Terlalu banyak percobaan. Coba lagi dalam 15 menit.';
        }
        if (row['purpose'] != 'INVALID') return null;
      } on PostgrestException catch (error) {
        if (error.code != '22023' && error.code != 'PGRST202') rethrow;
      }
      await _client
          .rpc('redeem_voucher', params: {'p_code': code.trim().toUpperCase()})
          .timeout(const Duration(seconds: 15));
      return null;
    } on TimeoutException {
      return 'Koneksi ke server terlalu lama. Silakan coba lagi.';
    } on PostgrestException catch (error) {
      return VoucherRedeemErrorMapper.fromPostgrest(error);
    } catch (_) {
      return 'Voucher belum dapat digunakan. Periksa koneksi lalu coba lagi.';
    }
  }
}

/// Converts backend voucher outcomes to safe, user-facing text. The RPC is
/// still the source of truth; this only controls how its failure is shown.
abstract final class VoucherRedeemErrorMapper {
  static String fromPostgrest(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (error.code == '28000') return 'Silakan masuk terlebih dahulu.';
    if (error.code == '42501') return 'Akses akun Anda dinonaktifkan.';
    if (message.contains('sudah pernah')) {
      return 'Voucher ini sudah pernah digunakan akun Anda.';
    }
    if (message.contains('habis digunakan')) {
      return 'Voucher sudah mencapai batas penggunaan.';
    }
    if (message.contains('tidak aktif')) return 'Voucher tidak aktif.';
    if (message.contains('belum dapat')) {
      return 'Voucher belum dapat digunakan.';
    }
    if (message.contains('berakhir')) return 'Voucher sudah kedaluwarsa.';
    if (message.contains('tidak valid')) return 'Kode voucher tidak valid.';
    return 'Voucher belum dapat digunakan. Silakan coba lagi.';
  }
}

final voucherRepositoryProvider = Provider<VoucherRepository>(
  (ref) => VoucherRepository(ref.watch(supabaseClientProvider)),
);
