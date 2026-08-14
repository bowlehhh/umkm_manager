import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/navigation_label_formatter.dart';
import '../../features/business_configuration/domain/business_capability_registry.dart';
import '../../features/business_configuration/domain/business_configuration.dart';
import '../../features/businesses/domain/business.dart';
import '../../features/cashier/presentation/views/cashier_page.dart';
import '../../features/customers/presentation/views/customers_page.dart';
import '../../features/dashboard/presentation/views/dashboard_page.dart';
import '../../features/products/presentation/views/products_page.dart';
import '../../features/settings/presentation/views/more_page.dart';
import '../../features/transactions/presentation/views/transactions_page.dart';
import 'development_preview_badge.dart';
import 'feature_placeholder_page.dart';

class MainNavigationScaffold extends ConsumerWidget {
  const MainNavigationScaffold({
    super.key,
    required this.business,
    required this.configuration,
    required this.currentRoute,
  });
  final Business business;
  final BusinessConfiguration configuration;
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features =
        configuration.features
            .where((item) => item.enabled)
            .map(
              (item) => (
                config: item,
                capability: BusinessCapabilityRegistry.byKey(item.key),
              ),
            )
            .where((item) => item.capability?.navigationPriority != null)
            .where((item) => item.capability!.template.isImplemented)
            .toList()
          ..sort(
            (a, b) => a.capability!.navigationPriority!.compareTo(
              b.capability!.navigationPriority!,
            ),
          );
    final primary = features.take(4).toList();
    final routes = [...primary.map((item) => item.capability!.route), '/more'];
    final selectedIndex = routes
        .indexOf(currentRoute)
        .clamp(0, routes.length - 1);
    final pages = [
      ...primary.map((item) => _pageFor(item.capability!, item.config)),
      MorePage(configuration: configuration),
    ];
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: selectedIndex, children: pages),
          if (ref.watch(appConfigProvider).isDevelopmentPreview)
            const Positioned(
              top: 12,
              right: 12,
              child: DevelopmentPreviewBadge(),
            ),
        ],
      ),
      bottomNavigationBar: _AdaptiveBottomNavigation(
        selectedIndex: selectedIndex,
        onSelected: (index) => context.go(routes[index]),
        items: [
          ...primary.map(
            (item) => _AdaptiveNavigationItem(
              icon: item.capability!.icon,
              label: NavigationLabelFormatter.compact(
                configuredName: item.config.name,
                capabilityName: item.capability!.name,
              ),
              fullLabel: item.config.name,
            ),
          ),
          const _AdaptiveNavigationItem(
            icon: Icons.grid_view_outlined,
            label: 'Lainnya',
            fullLabel: 'Lainnya',
          ),
        ],
      ),
    );
  }

  Widget _pageFor(
    BusinessCapability capability,
    BusinessFeatureConfig feature,
  ) => switch (capability.key) {
    'dashboard' => DashboardPage(
      key: ValueKey('dashboard-${business.id}'),
      business: business,
      configuration: configuration,
    ),
    'transactions' => TransactionsPage(
      key: ValueKey('transactions-${business.id}'),
      business: business,
    ),
    'cashier' => CashierPage(
      key: ValueKey('cashier-${business.id}'),
      business: business,
    ),
    'products' => ProductsPage(
      key: ValueKey('products-${business.id}'),
      business: business,
    ),
    'customers' => CustomersPage(
      key: ValueKey('customers-${business.id}'),
      business: business,
    ),
    _ => FeaturePlaceholderPage(
      title: feature.name,
      icon: capability.icon,
      description: 'Modul ${feature.name} telah aktif dan sedang disiapkan.',
    ),
  };
}

class _AdaptiveNavigationItem {
  const _AdaptiveNavigationItem({
    required this.icon,
    required this.label,
    required this.fullLabel,
  });

  final IconData icon;
  final String label;
  final String fullLabel;
}

class _AdaptiveBottomNavigation extends StatelessWidget {
  const _AdaptiveBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdaptiveNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          final height = compact ? 72.0 : 82.0;
          final fontSize = compact ? 10.0 : 11.0;
          return SizedBox(
            height: height,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _AdaptiveNavigationDestination(
                      item: items[index],
                      selected: selectedIndex == index,
                      fontSize: fontSize,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _AdaptiveNavigationDestination extends StatelessWidget {
  const _AdaptiveNavigationDestination({
    required this.item,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });

  final _AdaptiveNavigationItem item;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF475569);
    return Semantics(
      button: true,
      selected: selected,
      label: item.fullLabel,
      child: Tooltip(
        message: item.fullLabel,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 24, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: fontSize,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
