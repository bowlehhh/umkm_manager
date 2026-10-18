import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/dashboard_summary.dart';
import 'mock_dashboard_repository.dart';
import 'supabase_dashboard_repository.dart';

abstract interface class DashboardRepository {
  Future<DashboardSummary> getTodaySummary(String businessId);
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  if (ref.watch(appConfigProvider).isDevelopmentPreview) {
    return const MockDashboardRepository();
  }
  return SupabaseDashboardRepository(ref.watch(supabaseClientProvider));
});

final dashboardSummaryProvider =
    FutureProvider.family<DashboardSummary, String>(
      (ref, businessId) =>
          ref.watch(dashboardRepositoryProvider).getTodaySummary(businessId),
    );
