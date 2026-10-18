import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/entitlement.dart';

abstract interface class EntitlementService {
  Future<Entitlement> getCurrentEntitlement();
}

class SupabaseEntitlementService implements EntitlementService {
  const SupabaseEntitlementService(this._client);

  final SupabaseClient _client;

  @override
  Future<Entitlement> getCurrentEntitlement() async {
    try {
      final result = await _client.rpc('get_current_access');
      final rows = result is List ? result : const [];
      if (rows.isEmpty || rows.first is! Map) {
        throw StateError('Akses akun tidak ditemukan.');
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      final expires = row['subscription_expires_at'];
      return Entitlement(
        isActive: row['subscription_active'] as bool? ?? false,
        accessEnabled: row['access_enabled'] as bool? ?? false,
        role: row['role'] as String? ?? 'user',
        planKey: row['plan_key'] as String?,
        expiresAt: expires is String ? DateTime.tryParse(expires) : null,
        aiQuota: row['ai_quota'] as int? ?? 0,
        aiUsed: (row['ai_used'] as num?)?.toInt() ?? 0,
      );
    } on PostgrestException {
      // Fail closed. A regular user must never receive local/legacy access
      // when the server-side entitlement decision cannot be read.
      rethrow;
    }
  }
}

final entitlementServiceProvider = Provider<EntitlementService>(
  (ref) => SupabaseEntitlementService(ref.watch(supabaseClientProvider)),
);
