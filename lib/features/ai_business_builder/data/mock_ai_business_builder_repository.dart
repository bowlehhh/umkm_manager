import '../../business_configuration/domain/business_configuration.dart';
import '../../business_configuration/domain/business_capability_registry.dart';
import '../domain/business_recommendation_request.dart';
import 'ai_business_builder_repository.dart';

/// Fixture lokal khusus Development Preview; tidak pernah menghubungi AI server.
class MockAiBusinessBuilderRepository implements AiBusinessBuilderRepository {
  const MockAiBusinessBuilderRepository();

  @override
  Future<BusinessConfiguration> recommend(
    BusinessRecommendationRequest request,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    final input =
        '${request.businessType} ${request.description} ${request.additionalNeeds}'
            .toLowerCase();
    final service =
        input.contains('foto') ||
        input.contains('photograph') ||
        input.contains('booking');
    final laundry = input.contains('laundry');
    final keys = <String>{
      ...(service
          ? ['dashboard', 'customers', 'transactions']
          : laundry
          ? ['dashboard', 'customers', 'transactions']
          : ['dashboard', 'products', 'cashier', 'transactions', 'customers']),
    };
    if (RegExp(r'\b(stok|bahan|barang|produk|menu)\b').hasMatch(input)) {
      keys.add('products');
    }
    if (RegExp(r'\b(kasir|pembayaran|jual|penjualan)\b').hasMatch(input)) {
      keys.add('cashier');
    }
    final names = {
      'dashboard': 'Beranda',
      'booking': 'Booking',
      'customers': 'Pelanggan',
      'projects': 'Project',
      'services': 'Paket jasa',
      'employees': 'Karyawan',
      'payments': 'DP & pelunasan',
      'expenses': 'Pengeluaran',
      'reports': 'Laporan',
      'orders': 'Order',
      'products': 'Produk',
      'stock': 'Stok',
      'cashier': 'Kasir',
      'transactions': 'Transaksi',
      'debts': 'Piutang',
    };
    return BusinessConfiguration(
      businessCategory: service
          ? 'photography'
          : laundry
          ? 'laundry'
          : 'retail',
      summary: service
          ? 'Usaha jasa berbasis booking dan project.'
          : laundry
          ? 'Usaha laundry dengan alur order hingga pengambilan.'
          : 'Usaha retail dengan transaksi dan persediaan.',
      features: keys
          .map(
            (key) => BusinessFeatureConfig(
              key: key,
              name: names[key]!,
              enabled: true,
              reason: 'Sesuai kebutuhan usaha yang Anda ceritakan.',
              actions: BusinessCapabilityRegistry.byKey(
                key,
              )!.template.actions.toList()..sort(),
            ),
          )
          .toList(),
      customFields: const [],
      workflow: const [],
      paymentRule: const PaymentRule(supportsDownPayment: false),
      dashboardWidgets: service
          ? const [
              'active_jobs',
              'upcoming_bookings',
              'revenue',
              'unpaid_invoices',
            ]
          : const ['today_sales', 'low_stock', 'transactions'],
    );
  }
}
