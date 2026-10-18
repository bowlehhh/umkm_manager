import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dashboard_summary.dart';
import 'dashboard_repository.dart';

class SupabaseDashboardRepository implements DashboardRepository {
  const SupabaseDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DashboardSummary> getTodaySummary(String businessId) async {
    final data = await _client.rpc(
      'get_dashboard_summary',
      params: {'p_business_id': businessId},
    );
    if (data is! Map) {
      throw const FormatException('Ringkasan dashboard tidak valid.');
    }
    return DashboardSummary.fromJson(Map<String, dynamic>.from(data));
  }
}
