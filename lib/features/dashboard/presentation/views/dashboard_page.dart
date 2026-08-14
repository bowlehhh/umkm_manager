import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../biometrics/presentation/controllers/biometric_session_notifier.dart';
import '../../../business_configuration/domain/business_configuration.dart';
import '../../../businesses/domain/business.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({
    super.key,
    required this.business,
    required this.configuration,
  });

  final Business business;
  final BusinessConfiguration configuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPreview = ref.watch(appConfigProvider).isDevelopmentPreview;
    final biometric = ref.read(biometricSessionNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextButton.icon(
          onPressed: () => context.go('/businesses/select'),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          label: Text(business.name, overflow: TextOverflow.ellipsis),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            textStyle: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ganti usaha',
            onPressed: () => context.go('/businesses/select'),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: isPreview ? 'Tentang mode preview' : 'Kunci aplikasi',
            onPressed: isPreview
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Mode preview aktif. Perubahan hanya tersimpan selama aplikasi terbuka.',
                      ),
                    ),
                  )
                : () {
                    if (!biometric.state.isEnabled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Aktifkan Login Biometrik di Pengaturan → Keamanan terlebih dahulu.',
                          ),
                        ),
                      );
                      return;
                    }
                    biometric.lock();
                  },
            icon: Icon(
              isPreview
                  ? Icons.info_outline_rounded
                  : Icons.lock_outline_rounded,
            ),
          ),
        ],
      ),
      body: _BusinessDashboard(
        business: business,
        configuration: configuration,
        showPreviewData: isPreview,
      ),
    );
  }
}

class _BusinessDashboard extends StatelessWidget {
  const _BusinessDashboard({
    required this.business,
    required this.configuration,
    required this.showPreviewData,
  });

  final Business business;
  final BusinessConfiguration configuration;
  final bool showPreviewData;

  @override
  Widget build(BuildContext context) {
    final enabled = configuration.features
        .where((item) => item.enabled)
        .map((item) => item.key)
        .toSet();
    final cards = _dashboardCards(configuration.dashboardWidgets);
    final actions = _quickActions(enabled);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _WelcomeCard(business: business, summary: configuration.summary),
        const SizedBox(height: 24),
        Text(
          'Ringkasan hari ini',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          const _NoDashboardCards()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.42,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) => _DashboardMetric(
              card: cards[index],
              showPreviewData: showPreviewData,
            ),
          ),
        const SizedBox(height: 24),
        Text('Aksi cepat', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (actions.isEmpty)
          const _NoQuickAction()
        else ...[
          _QuickAction(data: actions.first, highlighted: true),
          if (actions.length > 1) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: actions
                      .skip(1)
                      .map(
                        (data) => SizedBox(
                          width: width,
                          child: _QuickAction(data: data),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ],
        const SizedBox(height: 24),
        if (showPreviewData && enabled.contains('stock'))
          _PreviewLowStockCard(itemLabel: business.type.itemLabel)
        else
          _GettingStartedCard(
            enabledFeatures: enabled,
            onTap: () => _startRoute(enabled),
          ),
      ],
    );
  }

  List<_DashboardCardData> _dashboardCards(List<String> widgetKeys) {
    const templates = <String, _DashboardCardData>{
      'active_jobs': _DashboardCardData(
        label: 'Job aktif',
        icon: Icons.folder_open_outlined,
        route: '/projects',
        previewValue: 7,
      ),
      'upcoming_bookings': _DashboardCardData(
        label: 'Booking mendatang',
        icon: Icons.calendar_month_outlined,
        route: '/booking',
        previewValue: 4,
      ),
      'revenue': _DashboardCardData(
        label: 'Pendapatan',
        icon: Icons.trending_up_rounded,
        route: '/transactions',
        isCurrency: true,
        previewValue: 1250000,
      ),
      'unpaid_invoices': _DashboardCardData(
        label: 'Tagihan belum lunas',
        icon: Icons.receipt_long_outlined,
        route: '/payments',
        isCurrency: true,
        previewValue: 175000,
      ),
      'today_sales': _DashboardCardData(
        label: 'Penjualan hari ini',
        icon: Icons.trending_up_rounded,
        route: '/transactions',
        isCurrency: true,
        previewValue: 1250000,
      ),
      'low_stock': _DashboardCardData(
        label: 'Stok menipis',
        icon: Icons.warning_amber_rounded,
        route: '/products',
        previewValue: 3,
      ),
      'transactions': _DashboardCardData(
        label: 'Transaksi',
        icon: Icons.receipt_long_outlined,
        route: '/transactions',
        previewValue: 12,
      ),
    };
    return widgetKeys
        .map((key) => templates[key])
        .whereType<_DashboardCardData>()
        .take(4)
        .toList();
  }

  List<_QuickActionData> _quickActions(Set<String> enabled) => [
    if (enabled.contains('cashier'))
      const _QuickActionData(
        icon: Icons.point_of_sale_rounded,
        title: 'Mulai Kasir',
        subtitle: 'Catat penjualan',
        route: '/cashier',
      ),
    if (enabled.contains('booking'))
      const _QuickActionData(
        icon: Icons.add_task_outlined,
        title: 'Buat booking',
        subtitle: 'Atur pesanan',
        route: '/booking',
      ),
    if (enabled.contains('orders'))
      const _QuickActionData(
        icon: Icons.add_shopping_cart_outlined,
        title: 'Buat order',
        subtitle: 'Catat pesanan',
        route: '/orders',
      ),
    if (enabled.contains('products'))
      const _QuickActionData(
        icon: Icons.add_box_outlined,
        title: 'Tambah produk',
        subtitle: 'Katalog usaha',
        route: '/products',
      ),
    if (enabled.contains('projects'))
      const _QuickActionData(
        icon: Icons.create_new_folder_outlined,
        title: 'Tambah project',
        subtitle: 'Pekerjaan baru',
        route: '/projects',
      ),
    if (enabled.contains('customers'))
      const _QuickActionData(
        icon: Icons.person_add_alt_1_outlined,
        title: 'Tambah pelanggan',
        subtitle: 'Data pelanggan',
        route: '/customers',
      ),
  ].take(3).toList();

  String _startRoute(Set<String> enabled) {
    if (enabled.contains('products')) return '/products';
    if (enabled.contains('booking')) return '/booking';
    if (enabled.contains('cashier')) return '/cashier';
    if (enabled.contains('orders')) return '/orders';
    return '/more';
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.business, required this.summary});
  final Business business;
  final String summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Beranda ${business.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DashboardCardData {
  const _DashboardCardData({
    required this.label,
    required this.icon,
    required this.route,
    this.previewValue = 0,
    this.isCurrency = false,
  });
  final String label;
  final IconData icon;
  final String route;
  final int previewValue;
  final bool isCurrency;
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.card, required this.showPreviewData});
  final _DashboardCardData card;
  final bool showPreviewData;

  @override
  Widget build(BuildContext context) {
    final value = showPreviewData ? card.previewValue : 0;
    final display = card.isCurrency
        ? CurrencyFormatter.rupiah(value)
        : '$value';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(card.route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(card.icon, color: Theme.of(context).colorScheme.primary),
              const Spacer(),
              Text(
                card.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(display, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.data, this.highlighted = false});
  final _QuickActionData data;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Card(
    color: highlighted ? Theme.of(context).colorScheme.primary : Colors.white,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.go(data.route),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: highlighted
                    ? Colors.white24
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                data.icon,
                color: highlighted ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: highlighted ? Colors.white : null,
                    ),
                  ),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: highlighted ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: highlighted ? Colors.white : AppColors.primary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard({
    required this.enabledFeatures,
    required this.onTap,
  });
  final Set<String> enabledFeatures;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rocket_launch_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mulai aktivitas usaha',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  enabledFeatures.contains('products')
                      ? 'Tambahkan produk pertama agar katalog dan transaksi siap digunakan.'
                      : 'Gunakan aksi cepat di atas untuk mulai mencatat aktivitas usaha.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Mulai sekarang'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewLowStockCard extends StatelessWidget {
  const _PreviewLowStockCard({required this.itemLabel});
  final String itemLabel;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.go('/products'),
      child: ListTile(
        leading: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.warning,
        ),
        title: Text('$itemLabel hampir habis'),
        subtitle: const Text('Keripik Pisang Cokelat • Sisa 3 bungkus'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    ),
  );
}

class _NoDashboardCards extends StatelessWidget {
  const _NoDashboardCards();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Text(
        'Ringkasan akan muncul setelah Anda mulai mencatat aktivitas usaha.',
      ),
    ),
  );
}

class _NoQuickAction extends StatelessWidget {
  const _NoQuickAction();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Text(
        'Aktifkan fitur dari konfigurasi usaha untuk melihat aksi cepat.',
      ),
    ),
  );
}
