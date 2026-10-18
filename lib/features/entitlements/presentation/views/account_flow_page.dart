import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/entitlement_service.dart';
import '../../domain/access_route_resolver.dart';
import '../../domain/entitlement.dart';

class AccountFlowPage extends ConsumerStatefulWidget {
  const AccountFlowPage({super.key});
  @override
  ConsumerState<AccountFlowPage> createState() => _AccountFlowPageState();
}

class _AccountFlowPageState extends ConsumerState<AccountFlowPage> {
  late Future<Entitlement> _ready = _check();
  Future<Entitlement> _check() async {
    // Profil dapat belum ada pada akun lama sebelum trigger auth/migration
    // terbaru diterapkan. Jangan blokir sesi yang sudah valid hanya karena
    // checkpoint profil ini; RPC pembuatan usaha telah memastikan profil ada.
    return ref.read(entitlementServiceProvider).getCurrentEntitlement();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Entitlement>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Akun belum dapat disiapkan. Periksa koneksi lalu coba lagi.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() => _ready = _check()),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final entitlement = snapshot.data!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AccessRouteResolver.authenticatedHome(entitlement));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    },
  );
}
