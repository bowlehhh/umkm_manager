import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/business.dart';
import 'business_repository.dart';

class SupabaseBusinessRepository implements BusinessRepository {
  const SupabaseBusinessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Business>> getBusinesses() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('business_members')
        .select(
          'role, is_active, business:businesses(id, name, address, phone, business_type)',
        )
        .eq('user_id', userId)
        .order('created_at');
    return rows
        .map((row) {
          final business = row['business'];
          if (business is! Map<String, dynamic>) return null;
          return Business.fromJson({
            ...business,
            'role': row['role'],
            'is_active': row['is_active'],
          });
        })
        .whereType<Business>()
        .toList(growable: false);
  }

  @override
  Future<Business?> getActiveBusiness() async {
    for (final business in await getBusinesses()) {
      if (business.isActive) return business;
    }
    return null;
  }

  @override
  Future<void> setActiveBusiness(String businessId) async {
    await _client.rpc(
      'set_active_business',
      params: {'target_business_id': businessId},
    );
  }

  @override
  Future<Business> createBusiness({
    required String name,
    required BusinessType type,
    String? address,
    String? phone,
  }) async {
    final result = await _client.rpc(
      'create_business_with_owner',
      params: {
        'business_name': name.trim(),
        'business_address': address?.trim(),
        'business_phone': phone?.trim(),
        'business_type': type.databaseValue,
      },
    );
    return Business.fromJson(result as Map<String, dynamic>);
  }
}
