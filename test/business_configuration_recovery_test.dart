import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/business_configuration/domain/business_capability_registry.dart';
import 'package:umkm_manager/features/business_configuration/domain/business_configuration.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';

void main() {
  const business = Business(
    id: 'business-1',
    name: 'Usaha Saya',
    type: BusinessType.retail,
  );

  test('konfigurasi yang hanya berisi dashboard dipulihkan ke paket dasar', () {
    const dashboardOnly = BusinessConfiguration(
      businessCategory: 'retail',
      summary: 'Beranda saja.',
      features: [
        BusinessFeatureConfig(
          key: 'dashboard',
          name: 'Beranda',
          enabled: true,
          reason: 'Awal',
          actions: ['view'],
        ),
      ],
      customFields: [],
      workflow: [],
      paymentRule: PaymentRule(supportsDownPayment: false),
      dashboardWidgets: ['today_sales'],
    );

    final recovered = BusinessCapabilityRegistry.usableConfiguration(
      business,
      dashboardOnly,
    );

    expect(
      recovered.features.where((item) => item.enabled).map((item) => item.key),
      containsAll([
        'dashboard',
        'products',
        'cashier',
        'transactions',
        'customers',
      ]),
    );
  });

  test('konfigurasi dengan fitur operasional tetap dipakai apa adanya', () {
    const configured = BusinessConfiguration(
      businessCategory: 'jasa',
      summary: 'Pelanggan dan transaksi.',
      features: [
        BusinessFeatureConfig(
          key: 'dashboard',
          name: 'Beranda',
          enabled: true,
          reason: 'Awal',
          actions: ['view'],
        ),
        BusinessFeatureConfig(
          key: 'customers',
          name: 'Klien',
          enabled: true,
          reason: 'Dibutuhkan',
          actions: ['list', 'create', 'view', 'edit', 'archive', 'search'],
        ),
      ],
      customFields: [],
      workflow: [],
      paymentRule: PaymentRule(supportsDownPayment: false),
      dashboardWidgets: ['transactions'],
    );

    expect(
      BusinessCapabilityRegistry.usableConfiguration(business, configured),
      same(configured),
    );
  });
}
