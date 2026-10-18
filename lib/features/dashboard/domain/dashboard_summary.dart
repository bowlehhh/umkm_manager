class DashboardSummary {
  const DashboardSummary({
    required this.totalTransactions,
    required this.grossRevenue,
    required this.totalExpense,
    required this.openDebtTotal,
    required this.customerCount,
    required this.lowStockCount,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        totalTransactions: json['total_transactions'] as int? ?? 0,
        grossRevenue: json['gross_revenue'] as int? ?? 0,
        totalExpense: json['total_expense'] as int? ?? 0,
        openDebtTotal: json['open_debt_total'] as int? ?? 0,
        customerCount: json['customer_count'] as int? ?? 0,
        lowStockCount: json['low_stock_count'] as int? ?? 0,
      );

  const DashboardSummary.preview()
    : totalTransactions = 12,
      grossRevenue = 1250000,
      totalExpense = 0,
      openDebtTotal = 175000,
      customerCount = 0,
      lowStockCount = 3;

  final int totalTransactions;
  final int grossRevenue;
  final int totalExpense;
  final int openDebtTotal;
  final int customerCount;
  final int lowStockCount;

  int valueFor(String widgetKey) => switch (widgetKey) {
    'revenue' || 'today_sales' => grossRevenue,
    'unpaid_invoices' => openDebtTotal,
    'low_stock' => lowStockCount,
    'transactions' => totalTransactions,
    _ => 0,
  };
}
