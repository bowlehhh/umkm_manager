import 'package:flutter/material.dart';

import '../../../../shared/widgets/development_preview_badge.dart';

class PreviewFeaturePage extends StatelessWidget {
  const PreviewFeaturePage({super.key, required this.feature});

  final PreviewFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(feature.title),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: DevelopmentPreviewBadge(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    feature.icon,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      feature.headline,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...feature.items.map(
            (item) => Card(
              child: ListTile(
                leading: Icon(item.$1),
                title: Text(item.$2),
                subtitle: Text(item.$3),
                trailing: item.$4 == null ? null : Text(item.$4!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum PreviewFeature {
  customers,
  debts,
  expenses,
  discounts,
  employees,
  reports,
  settings;

  String get title => switch (this) {
    customers => 'Pelanggan',
    debts => 'Bon / Piutang',
    expenses => 'Pengeluaran',
    discounts => 'Diskon',
    employees => 'Karyawan',
    reports => 'Laporan',
    settings => 'Pengaturan',
  };

  IconData get icon => switch (this) {
    customers => Icons.people_outline_rounded,
    debts => Icons.account_balance_wallet_outlined,
    expenses => Icons.payments_outlined,
    discounts => Icons.percent_rounded,
    employees => Icons.badge_outlined,
    reports => Icons.bar_chart_rounded,
    settings => Icons.settings_outlined,
  };

  String get headline => switch (this) {
    customers => '24 pelanggan terdaftar',
    debts => '3 bon belum lunas',
    expenses => 'Pengeluaran hari ini Rp85.000',
    discounts => '2 promo sedang aktif',
    employees => '3 anggota tim aktif',
    reports => 'Ringkasan bulan ini',
    settings => 'Atur bisnis dan aplikasi',
  };

  List<(IconData, String, String, String?)> get items => switch (this) {
    customers => [
      (Icons.person_outline, 'Andi Pratama', '12 transaksi', 'Rp450.000'),
      (Icons.person_outline, 'Siti Rahma', '8 transaksi', 'Rp280.000'),
    ],
    debts => [
      (
        Icons.schedule_outlined,
        'Andi Pratama',
        'Sisa bon • jatuh tempo 12 Agu',
        'Rp100.000',
      ),
      (
        Icons.schedule_outlined,
        'Budi Santoso',
        'Sisa bon • jatuh tempo 15 Agu',
        'Rp75.000',
      ),
    ],
    expenses => [
      (Icons.bolt_outlined, 'Listrik', 'Hari ini', 'Rp50.000'),
      (Icons.local_shipping_outlined, 'Transportasi', 'Hari ini', 'Rp35.000'),
    ],
    discounts => [
      (
        Icons.local_offer_outlined,
        'Promo Jumat',
        '10% • min. Rp50.000',
        'Aktif',
      ),
      (Icons.local_offer_outlined, 'Diskon Pelanggan Baru', 'Rp5.000', 'Aktif'),
    ],
    employees => [
      (Icons.person_outline, 'Dewi Lestari', 'ADMIN', 'Aktif'),
      (Icons.person_outline, 'Rizky Maulana', 'CASHIER', 'Aktif'),
    ],
    reports => [
      (Icons.trending_up_rounded, 'Omzet', '1–8 Agustus', 'Rp4.850.000'),
      (
        Icons.account_balance_outlined,
        'Laba bersih',
        '1–8 Agustus',
        'Rp1.425.000',
      ),
    ],
    settings => [
      (Icons.storefront_outlined, 'Profil bisnis', 'Kedai Nusantara', null),
      (Icons.security_outlined, 'Role & hak akses', 'Kelola tim Anda', null),
    ],
  };
}
