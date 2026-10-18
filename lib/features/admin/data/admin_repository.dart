import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

/// A deliberately safe error for the admin UI. Database messages are never
/// passed through to an administrator's screen.
class AdminVoucherException implements Exception {
  const AdminVoucherException(this.message, {this.code});

  final String message;
  final String? code;
}

/// The exact production PostgREST contract for public.admin_create_voucher.
/// Keeping it as a value object makes parameter names and runtime types
/// independently testable, instead of relying on an inline map in the UI.
class AdminVoucherCreatePayload {
  const AdminVoucherCreatePayload({
    required this.code,
    required this.label,
    required this.durationDays,
    required this.aiQuota,
    required this.maxRedemptions,
    required this.startsAt,
    required this.expiresAt,
    required this.planKey,
  });

  static const rpcName = 'admin_create_voucher';
  static const defaultPlanKey = 'voucher';

  final String code;
  final String label;
  final int durationDays;
  final int? aiQuota;
  final int maxRedemptions;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final String planKey;

  Map<String, dynamic> toRpcParams() => {
    'p_code': code.trim().toUpperCase(),
    'p_label': label.trim(),
    'p_duration_days': durationDays,
    'p_ai_quota': aiQuota,
    'p_max_redemptions': maxRedemptions,
    'p_starts_at': startsAt?.toUtc().toIso8601String(),
    'p_expires_at': expiresAt?.toUtc().toIso8601String(),
    'p_plan_key': planKey.trim(),
  };

  /// Contains no values, notably no voucher code. Safe for debug builds.
  Map<String, String> get safeParameterTypes => {
    'p_code': 'String',
    'p_label': 'String',
    'p_duration_days': 'int',
    'p_ai_quota': aiQuota == null ? 'null' : 'int',
    'p_max_redemptions': 'int',
    'p_starts_at': startsAt == null ? 'null' : 'ISO-8601 String',
    'p_expires_at': expiresAt == null ? 'null' : 'ISO-8601 String',
    'p_plan_key': 'String',
  };

  /// Runtime types are logged without parameter values.
  Map<String, String> get safeParameterRuntimeTypes => toRpcParams().map(
    (name, value) => MapEntry(name, value?.runtimeType.toString() ?? 'null'),
  );
}

abstract final class AdminVoucherDiagnostic {
  /// Preserves the original backend diagnostic where possible, while removing
  /// the submitted voucher and credential-shaped content before debug output.
  static String safeText(Object? value, {required String voucherCode}) {
    var text = value?.toString() ?? 'null';
    final normalizedCode = voucherCode.trim();
    if (normalizedCode.isNotEmpty) {
      text = text.replaceAll(
        RegExp(RegExp.escape(normalizedCode), caseSensitive: false),
        '[REDACTED_VOUCHER]',
      );
    }
    text = text.replaceAllMapped(
      RegExp(r'\bbearer\s+[^,;\s]+', caseSensitive: false),
      (_) => 'Bearer [REDACTED]',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'\b(authorization|access[_ -]?token|refresh[_ -]?token|api[_ -]?key|service[_ -]?role|password)\b\s*[:=]\s*[^,;\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=[REDACTED]',
    );
    return text.length <= 1500 ? text : '${text.substring(0, 1500)}…';
  }
}

abstract final class AdminVoucherErrorMapper {
  static AdminVoucherException create(PostgrestException error) {
    // PGRST202/42883 are the only cases categorised as a missing function.
    // The create request below uses the complete SQL parameter signature.
    if (error.code == 'PGRST202' || error.code == '42883') {
      return const AdminVoucherException(
        'Layanan voucher belum tersedia.',
        code: 'function_not_found',
      );
    }
    if (error.code == '42501' || error.code == 'PGRST301') {
      return const AdminVoucherException(
        'Anda tidak memiliki izin membuat voucher.',
        code: 'permission_denied',
      );
    }
    if (error.code == '23505') {
      return const AdminVoucherException(
        'Kode voucher sudah digunakan.',
        code: 'duplicate',
      );
    }
    if (error.code == '22023' || error.code == '23514') {
      return const AdminVoucherException(
        'Data voucher tidak valid. Periksa kode, durasi, quota, dan batas redeem.',
        code: 'invalid_input',
      );
    }
    return const AdminVoucherException(
      'Terjadi gangguan pada server. Silakan coba lagi.',
      code: 'server_error',
    );
  }
}

class AdminRepository {
  const AdminRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> dashboard() async =>
      _map(await _client.rpc('admin_dashboard_metrics'));

  Future<Map<String, dynamic>> aiUsage() async =>
      _map(await _client.rpc('admin_ai_usage_summary'));

  Future<List<Map<String, dynamic>>> users({
    String? search,
    String? status,
    String? role,
  }) async => _rows(
    await _client.rpc(
      'admin_list_users_v2',
      params: {
        'p_search': search?.trim().isEmpty ?? true ? null : search,
        'p_status': status,
        'p_role': role,
      },
    ),
  );

  Future<List<Map<String, dynamic>>> vouchers() async => _rows(
    await _client.rpc(
      'admin_list_vouchers',
      params: const {'p_limit': 50, 'p_offset': 0},
    ),
  );

  Future<List<Map<String, dynamic>>> invitations({
    String? status,
    String? purpose,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => _rows(
    await _client.rpc(
      'admin_list_invitations',
      params: {
        'p_status': status,
        'p_purpose': purpose,
        'p_search': search?.trim().isEmpty ?? true ? null : search,
        'p_limit': limit,
        'p_offset': offset,
      },
    ),
  );

  Future<String> createInvitation({
    required String purpose,
    required DateTime expiresAt,
    String? email,
    String? businessId,
    String? businessRole,
    DateTime? promotionEndsAt,
    int? promotionQuota,
    String? reason,
  }) async {
    final result = await _client.rpc(
      'admin_create_invitation',
      params: {
        'p_purpose': purpose,
        'p_expires_at': expiresAt.toUtc().toIso8601String(),
        'p_email': email?.trim().isEmpty ?? true ? null : email?.trim(),
        'p_business_id': businessId?.trim().isEmpty ?? true
            ? null
            : businessId?.trim(),
        'p_business_role': businessRole,
        'p_promotion_ends_at': promotionEndsAt?.toUtc().toIso8601String(),
        'p_promotion_quota': promotionQuota,
        'p_reason': reason?.trim().isEmpty ?? true ? null : reason?.trim(),
      },
    );
    final rows = _rows(result);
    final token = rows.isEmpty ? null : rows.first['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Server tidak mengembalikan token undangan.');
    }
    return token;
  }

  Future<void> revokeInvitation(String invitationId) => _client.rpc(
    'admin_revoke_invitation',
    params: {'p_invitation_id': invitationId},
  );

  Future<void> setUserRole(String userId, String role) => _client.rpc(
    'admin_set_user_role',
    params: {'p_user_id': userId, 'p_role': role},
  );

  Future<void> setUserAccess(String userId, bool enabled) => _client.rpc(
    'admin_set_user_access',
    params: {'p_user_id': userId, 'p_enabled': enabled},
  );

  /// Contract copied from production: (text, text, integer, integer,
  /// integer, timestamptz, timestamptz, text) -> uuid.
  Future<String> createVoucher({
    required String code,
    required String label,
    required int durationDays,
    int? aiQuota,
    required int maxRedemptions,
    DateTime? startsAt,
    DateTime? expiresAt,
    String planKey = AdminVoucherCreatePayload.defaultPlanKey,
  }) async {
    if (planKey.trim().isEmpty) {
      throw const AdminVoucherException(
        'Paket voucher tidak valid.',
        code: 'invalid_plan_key',
      );
    }
    final payload = AdminVoucherCreatePayload(
      code: code,
      label: label,
      durationDays: durationDays,
      aiQuota: aiQuota,
      maxRedemptions: maxRedemptions,
      startsAt: startsAt,
      expiresAt: expiresAt,
      planKey: planKey,
    );
    const rpcName = AdminVoucherCreatePayload.rpcName;
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _client
          .rpc(rpcName, params: payload.toRpcParams())
          .timeout(const Duration(seconds: 15));
      if (result is! String || result.isEmpty) {
        throw const AdminVoucherException('Respons voucher tidak valid.');
      }
      _debugVoucherRpc(
        rpcName: rpcName,
        duration: stopwatch.elapsed,
        safeMessage: 'success',
        parameterTypes: payload.safeParameterRuntimeTypes,
      );
      return result;
    } on TimeoutException {
      _debugVoucherRpc(
        rpcName: rpcName,
        duration: stopwatch.elapsed,
        code: 'timeout',
        safeMessage: 'network timeout',
        parameterTypes: payload.safeParameterRuntimeTypes,
      );
      throw const AdminVoucherException(
        'Koneksi ke server gagal. Silakan coba lagi.',
        code: 'timeout',
      );
    } on PostgrestException catch (error) {
      // Must run before error mapping so development sees the actual response
      // returned by Supabase/PostgREST, with sensitive content redacted.
      _debugPostgrestFailure(
        rpcName: rpcName,
        error: error,
        payload: payload,
        duration: stopwatch.elapsed,
      );
      final mapped = AdminVoucherErrorMapper.create(error);
      _debugVoucherRpc(
        rpcName: rpcName,
        duration: stopwatch.elapsed,
        code: error.code,
        safeMessage: '${mapped.code}: ${mapped.message}',
        parameterTypes: payload.safeParameterRuntimeTypes,
      );
      throw mapped;
    } on AdminVoucherException catch (error) {
      _debugVoucherRpc(
        rpcName: rpcName,
        duration: stopwatch.elapsed,
        code: error.code,
        safeMessage: error.message,
        parameterTypes: payload.safeParameterRuntimeTypes,
      );
      rethrow;
    } catch (error) {
      _debugVoucherRpc(
        rpcName: rpcName,
        duration: stopwatch.elapsed,
        safeMessage: 'unknown server error (${error.runtimeType})',
        parameterTypes: payload.safeParameterRuntimeTypes,
      );
      throw const AdminVoucherException(
        'Terjadi gangguan pada server. Silakan coba lagi.',
      );
    }
  }

  void _debugVoucherRpc({
    required String rpcName,
    required Duration duration,
    required String safeMessage,
    String? code,
    Map<String, String>? parameterTypes,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[voucher-rpc] name=$rpcName code=${code ?? 'ok'} '
      'duration_ms=${duration.inMilliseconds} message=$safeMessage '
      'parameter_names=${parameterTypes?.keys.join(',') ?? '-'} '
      'parameter_types=${parameterTypes ?? const {}}',
    );
  }

  void _debugPostgrestFailure({
    required String rpcName,
    required PostgrestException error,
    required AdminVoucherCreatePayload payload,
    required Duration duration,
  }) {
    if (!kDebugMode) return;
    String redact(Object? value) =>
        AdminVoucherDiagnostic.safeText(value, voucherCode: payload.code);
    debugPrint(
      '[voucher-rpc-diagnostic] rpc_name=$rpcName '
      'success=false exception_runtime_type=${error.runtimeType} '
      'postgrest_code=${error.code ?? 'null'} '
      'postgrest_message=${redact(error.message)} '
      'postgrest_details=${redact(error.details)} '
      'postgrest_hint=${redact(error.hint)} '
      'parameter_names=${payload.toRpcParams().keys.join(',')} '
      'parameter_runtime_types=${payload.safeParameterRuntimeTypes} '
      'duration_ms=${duration.inMilliseconds}',
    );
  }

  Future<void> setVoucherStatus(String voucherId, String status) => _client.rpc(
    'admin_set_voucher_status',
    params: {'p_voucher_id': voucherId, 'p_status': status},
  );

  Future<List<Map<String, dynamic>>> subscriptions({String? status}) async =>
      _rows(
        await _client.rpc(
          'admin_list_subscriptions',
          params: {'p_status': status},
        ),
      );

  Future<List<Map<String, dynamic>>> paymentSubmissions({
    String? status = 'PENDING',
  }) async => _rows(
    await _client.rpc(
      'admin_list_payment_submissions',
      params: {'p_status': status, 'p_limit': 100, 'p_offset': 0},
    ),
  );

  Future<void> reviewPayment({
    required String submissionId,
    required bool approve,
    String? reason,
  }) => _client.rpc(
    'admin_review_manual_payment',
    params: {
      'p_submission_id': submissionId,
      'p_approve': approve,
      'p_reason': reason,
    },
  );

  Future<Map<String, dynamic>> userDetail(String userId) async => _map(
    await _client.rpc('admin_user_detail', params: {'p_user_id': userId}),
  );

  Future<void> activateSubscription({
    required String userId,
    required int durationDays,
    String planKey = 'voucher',
    int? aiQuota,
  }) => _client.rpc(
    'admin_activate_subscription',
    params: {
      'p_user_id': userId,
      'p_plan_key': planKey,
      'p_duration_days': durationDays,
      'p_ai_quota': aiQuota,
    },
  );

  Future<void> extendSubscription(String userId, int durationDays) =>
      _client.rpc(
        'admin_extend_subscription',
        params: {'p_user_id': userId, 'p_duration_days': durationDays},
      );

  Future<void> setSubscriptionStatus(String userId, String status) =>
      _client.rpc(
        'admin_set_subscription_status',
        params: {'p_user_id': userId, 'p_status': status},
      );

  Future<List<Map<String, dynamic>>> voucherRedemptions(
    String voucherId,
  ) async => _rows(
    await _client.rpc(
      'admin_list_voucher_redemptions',
      params: {'p_voucher_id': voucherId, 'p_limit': 50, 'p_offset': 0},
    ),
  );

  Future<List<Map<String, dynamic>>> aiUsageByUser({int days = 30}) async {
    final to = DateTime.now().toUtc();
    final from = to.subtract(Duration(days: days));
    return _rows(
      await _client.rpc(
        'admin_list_ai_usage_users',
        params: {
          'p_from': from.toIso8601String(),
          'p_to': to.toIso8601String(),
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> businesses() async =>
      _rows(await _client.rpc('admin_list_businesses'));

  Future<List<Map<String, dynamic>>> errorLogs({bool? resolved}) async => _rows(
    await _client.rpc(
      'admin_list_error_logs',
      params: {'p_resolved': resolved},
    ),
  );

  Future<void> setErrorResolved(String errorId, bool resolved) => _client.rpc(
    'admin_set_error_resolved',
    params: {'p_error_id': errorId, 'p_resolved': resolved},
  );

  Future<List<Map<String, dynamic>>> auditLogs({
    String? source,
    String? action,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => _rows(
    await _client.rpc(
      'admin_list_activity_audit',
      params: {
        'p_source': source,
        'p_action': action,
        'p_search': search?.trim().isEmpty ?? true ? null : search,
        'p_limit': limit,
        'p_offset': offset,
      },
    ),
  );

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);
