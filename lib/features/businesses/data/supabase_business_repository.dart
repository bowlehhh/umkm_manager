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
    // Ambil membership dan data usaha secara terpisah. Relasi embedded
    // PostgREST dapat bernilai null pada sebagian konfigurasi schema-cache,
    // yang sebelumnya membuat akun berusaha terlihat tidak memiliki usaha.
    final membershipRows = await _client
        .from('business_members')
        .select('business_id, role, is_active')
        .eq('user_id', userId)
        .order('created_at');
    final memberships = List<Map<String, dynamic>>.from(membershipRows);
    final businessIds = memberships
        .map((row) => row['business_id'])
        .whereType<String>()
        .toList(growable: false);
    if (businessIds.isEmpty) return const [];

    final businessRows = await _client
        .from('businesses')
        .select('id, name, address, phone, business_type')
        .inFilter('id', businessIds);

    return mapBusinessMemberships(
      memberships,
      List<Map<String, dynamic>>.from(businessRows),
    );
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

List<Business> mapBusinessMemberships(
  Iterable<Map<String, dynamic>> memberships,
  Iterable<Map<String, dynamic>> businesses,
) {
  final businessesById = {
    for (final business in businesses)
      if (business['id'] is String) business['id'] as String: business,
  };
  return memberships
      .map((membership) {
        final businessId = membership['business_id'];
        if (businessId is! String) return null;
        final business = businessesById[businessId];
        if (business == null) return null;
        return Business.fromJson({
          ...business,
          'role': membership['role'],
          'is_active': membership['is_active'],
        });
      })
      .whereType<Business>()
      .toList(growable: false);
}
