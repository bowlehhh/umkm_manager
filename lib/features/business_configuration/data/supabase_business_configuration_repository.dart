import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/business_configuration.dart';
import 'business_configuration_repository.dart';

class SupabaseBusinessConfigurationRepository
    implements BusinessConfigurationRepository {
  const SupabaseBusinessConfigurationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<BusinessConfiguration?> getConfiguration(String businessId) async {
    final row = await _client
        .from('business_configurations')
        .select('configuration')
        .eq('business_id', businessId)
        .maybeSingle();
    if (row == null) return null;
    final config = row['configuration'];
    if (config is! Map) {
      throw const FormatException('Konfigurasi bisnis tersimpan tidak valid.');
    }
    return BusinessConfiguration.fromJson(Map<String, dynamic>.from(config));
  }

  @override
  Future<void> saveConfiguration(
    String businessId,
    BusinessConfiguration configuration,
  ) => _client.from('business_configurations').upsert({
    'business_id': businessId,
    'configuration': configuration.toJson(),
  });
}
