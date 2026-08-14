import 'package:flutter/material.dart';

import 'business_configuration.dart';
import '../../businesses/domain/business.dart';

class BusinessCapability {
  const BusinessCapability({
    required this.key,
    required this.name,
    required this.icon,
    required this.description,
    required this.route,
    this.navigationPriority,
  });
  final String key;
  final String name;
  final IconData icon;
  final String description;
  final String route;
  final int? navigationPriority;

  FeatureCapabilityTemplate get template =>
      FeatureCapabilityTemplates.forKey(key);
}

/// Daftar tunggal capability yang boleh direkomendasikan AI dan dirender app.
abstract final class BusinessCapabilityRegistry {
  static const all = <BusinessCapability>[
    BusinessCapability(
      key: 'dashboard',
      name: 'Beranda',
      icon: Icons.home_outlined,
      description: 'Ringkasan usaha',
      route: '/dashboard',
      navigationPriority: 0,
    ),
    BusinessCapability(
      key: 'products',
      name: 'Produk',
      icon: Icons.inventory_2_outlined,
      description: 'Katalog produk atau barang',
      route: '/products',
      navigationPriority: 3,
    ),
    BusinessCapability(
      key: 'stock',
      name: 'Stok',
      icon: Icons.warehouse_outlined,
      description: 'Persediaan barang',
      route: '/stock',
    ),
    BusinessCapability(
      key: 'cashier',
      name: 'Kasir',
      icon: Icons.point_of_sale_outlined,
      description: 'Penjualan di kasir',
      route: '/cashier',
      navigationPriority: 2,
    ),
    BusinessCapability(
      key: 'transactions',
      name: 'Transaksi',
      icon: Icons.receipt_long_outlined,
      description: 'Riwayat penjualan',
      route: '/transactions',
      navigationPriority: 1,
    ),
    BusinessCapability(
      key: 'customers',
      name: 'Pelanggan',
      icon: Icons.people_outline,
      description: 'Data pelanggan',
      route: '/customers',
      navigationPriority: 3,
    ),
    BusinessCapability(
      key: 'debts',
      name: 'Piutang',
      icon: Icons.account_balance_wallet_outlined,
      description: 'Tagihan pelanggan',
      route: '/debts',
    ),
    BusinessCapability(
      key: 'expenses',
      name: 'Pengeluaran',
      icon: Icons.payments_outlined,
      description: 'Biaya usaha',
      route: '/expenses',
    ),
    BusinessCapability(
      key: 'discounts',
      name: 'Diskon',
      icon: Icons.sell_outlined,
      description: 'Promo dan diskon',
      route: '/discounts',
    ),
    BusinessCapability(
      key: 'employees',
      name: 'Karyawan',
      icon: Icons.badge_outlined,
      description: 'Tim usaha',
      route: '/employees',
    ),
    BusinessCapability(
      key: 'reports',
      name: 'Laporan',
      icon: Icons.bar_chart_outlined,
      description: 'Laporan usaha',
      route: '/reports',
    ),
    BusinessCapability(
      key: 'booking',
      name: 'Booking',
      icon: Icons.calendar_month_outlined,
      description: 'Pemesanan berdasarkan waktu',
      route: '/booking',
      navigationPriority: 1,
    ),
    BusinessCapability(
      key: 'appointments',
      name: 'Janji temu',
      icon: Icons.event_available_outlined,
      description: 'Jadwal layanan',
      route: '/appointments',
    ),
    BusinessCapability(
      key: 'services',
      name: 'Layanan',
      icon: Icons.design_services_outlined,
      description: 'Paket jasa',
      route: '/services',
    ),
    BusinessCapability(
      key: 'projects',
      name: 'Project',
      icon: Icons.folder_open_outlined,
      description: 'Pekerjaan per klien',
      route: '/projects',
      navigationPriority: 2,
    ),
    BusinessCapability(
      key: 'orders',
      name: 'Order',
      icon: Icons.shopping_bag_outlined,
      description: 'Pesanan kerja',
      route: '/orders',
    ),
    BusinessCapability(
      key: 'payments',
      name: 'Pembayaran',
      icon: Icons.credit_card_outlined,
      description: 'DP dan pelunasan',
      route: '/payments',
    ),
  ];
  static BusinessCapability? byKey(String key) =>
      all.where((item) => item.key == key).firstOrNull;
  static bool supportsField(String featureKey, CustomFieldType type) =>
      byKey(featureKey) != null && CustomFieldType.values.contains(type);
  static FeatureCapabilityTemplate? templateFor(String key) =>
      FeatureCapabilityTemplates.all[key];

  /// Usaha lama tetap dapat berjalan sebelum memilih konfigurasi AI.
  static BusinessConfiguration legacyConfiguration(Business business) {
    // Jangan tampilkan capability lama yang belum memiliki modul lengkap.
    // Ini mencegah usaha lama mendapatkan menu yang berakhir di placeholder.
    const keys = [
      'dashboard',
      'transactions',
      'cashier',
      'products',
      'customers',
    ];
    return BusinessConfiguration(
      businessCategory: business.type.databaseValue.toLowerCase(),
      summary: 'Konfigurasi fitur usaha yang sudah ada.',
      features: keys.map((key) {
        final item = byKey(key)!;
        return BusinessFeatureConfig(
          key: key,
          name: item.name,
          enabled: true,
          reason: 'Fitur bawaan usaha.',
          actions: item.template.actions.toList()..sort(),
        );
      }).toList(),
      customFields: const [],
      workflow: const [],
      paymentRule: const PaymentRule(supportsDownPayment: false),
      dashboardWidgets: const ['today_sales', 'transactions'],
    );
  }
}
