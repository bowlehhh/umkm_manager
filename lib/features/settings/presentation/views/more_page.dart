import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../business_configuration/domain/business_capability_registry.dart';
import '../../../business_configuration/domain/business_configuration.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.configuration});
  final BusinessConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    final menu = configuration.features
        .where((item) => item.enabled && item.key != 'dashboard')
        .map(
          (item) => (
            config: item,
            capability: BusinessCapabilityRegistry.byKey(item.key),
          ),
        )
        .where(
          (item) =>
              item.capability != null &&
              item.capability!.template.isImplemented,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: menu.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == menu.length) {
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Pengaturan'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/settings'),
              ),
            );
          }
          final item = menu[index];
          return Card(
            child: ListTile(
              leading: Icon(
                item.capability!.icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(item.config.name),
              subtitle: Text(item.capability!.description),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(item.capability!.route),
            ),
          );
        },
      ),
    );
  }
}
