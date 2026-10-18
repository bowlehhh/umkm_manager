import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class BusinessReport {
  const BusinessReport({
    required this.transactionCount,
    required this.grossSales,
    required this.discounts,
    required this.netSales,
    required this.cogs,
    required this.operatingExpenses,
    required this.items,
  });
  factory BusinessReport.fromJson(Map<String, dynamic> json) => BusinessReport(
    transactionCount: (json['transaction_count'] as num).toInt(),
    grossSales: (json['gross_sales'] as num).toInt(),
    discounts: (json['discounts'] as num).toInt(),
    netSales: (json['net_sales'] as num).toInt(),
    cogs: (json['cogs'] as num).toInt(),
    operatingExpenses: (json['operating_expenses'] as num).toInt(),
    items: (json['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReportItem.fromJson)
        .toList(growable: false),
  );
  final int transactionCount;
  final int grossSales;
  final int discounts;
  final int netSales;
  final int cogs;
  final int operatingExpenses;
  final List<ReportItem> items;
  int get grossProfit => netSales - cogs;
  int get simpleResult => grossProfit - operatingExpenses;
}

class ReportItem {
  const ReportItem({
    required this.name,
    required this.quantity,
    required this.sales,
  });
  factory ReportItem.fromJson(Map<String, dynamic> json) => ReportItem(
    name: json['name'] as String,
    quantity: (json['quantity'] as num).toInt(),
    sales: (json['sales'] as num).toInt(),
  );
  final String name;
  final int quantity;
  final int sales;
}

class ReportRepository {
  const ReportRepository(this._client);
  final SupabaseClient _client;
  Future<BusinessReport> get({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) async {
    final data = await _client.rpc(
      'get_business_report',
      params: {
        'p_business_id': businessId,
        'p_start_date': start.toIso8601String().substring(0, 10),
        'p_end_date': end.toIso8601String().substring(0, 10),
      },
    );
    return BusinessReport.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final reportRepositoryProvider = Provider(
  (ref) => ReportRepository(ref.watch(supabaseClientProvider)),
);
