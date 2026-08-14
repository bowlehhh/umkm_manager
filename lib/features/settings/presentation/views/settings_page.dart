import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
