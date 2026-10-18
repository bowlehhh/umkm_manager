import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/dashboard/domain/dashboard_summary.dart';

void main() {
  test(
    'dashboard summary maps the compact RPC payload to dashboard metrics',
    () {
      final summary = DashboardSummary.fromJson({
        'total_transactions': 12,
        'gross_revenue': 1250000,
        'total_expense': 50000,
        'open_debt_total': 175000,
        'customer_count': 8,
        'low_stock_count': 3,
      });

      expect(summary.valueFor('today_sales'), 1250000);
      expect(summary.valueFor('transactions'), 12);
      expect(summary.valueFor('unpaid_invoices'), 175000);
      expect(summary.valueFor('low_stock'), 3);
      expect(summary.valueFor('active_jobs'), 0);
    },
  );
}
