import '../domain/dashboard_summary.dart';
import 'dashboard_repository.dart';

class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository();

  @override
  Future<DashboardSummary> getTodaySummary(String businessId) async =>
      const DashboardSummary.preview();
}
