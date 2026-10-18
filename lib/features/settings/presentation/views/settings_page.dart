import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../business_configuration/domain/business_configuration.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.businessId,
    required this.configuration,
  });

  final String businessId;
  final BusinessConfiguration configuration;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Langganan dan kuota AI'),
            subtitle: const Text('Paket, tagihan manual, dan sisa kuota'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/subscription'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Usaha saya'),
            subtitle: const Text(
              'Pilih usaha atau tambahkan usaha baru pada akun ini',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/businesses/select'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Fitur usaha'),
            subtitle: Text(
              '${configuration.features.where((item) => item.enabled).length} fitur aktif. Ubah atau batalkan rekomendasi AI.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/features'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Keamanan'),
            subtitle: const Text('Login biometrik pada perangkat ini'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/security'),
          ),
        ),
      ],
    ),
  );
}
