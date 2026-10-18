import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/entitlement_service.dart';
import '../../data/voucher_repository.dart';
import '../../domain/entitlement.dart';

class AccessExpiredPage extends ConsumerStatefulWidget {
  const AccessExpiredPage({super.key});

  @override
  ConsumerState<AccessExpiredPage> createState() => _AccessExpiredPageState();
}

class _AccessExpiredPageState extends ConsumerState<AccessExpiredPage> {
  final _code = TextEditingController();
  bool _loading = false;
  late final Future<Entitlement> _entitlement = _loadEntitlement();

  Future<Entitlement> _loadEntitlement() =>
      ref.read(entitlementServiceProvider).getCurrentEntitlement();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_loading) return;
    final code = _code.text.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan kode voucher yang valid.')),
      );
      return;
    }
    setState(() => _loading = true);
    FocusScope.of(context).unfocus();
    final error = await ref.read(voucherRepositoryProvider).redeem(code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Akses berhasil diaktifkan.')));
    context.go('/account');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aktifkan akses')),
    body: FutureBuilder<Entitlement>(
      future: _entitlement,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final disabled = !snapshot.data!.accessEnabled;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.card_giftcard_rounded, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    disabled ? 'Akses akun dinonaktifkan' : 'Aktifkan akses',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Masukkan kode voucher yang diberikan admin untuk mulai menggunakan UMKM Manager.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (disabled)
                    const Text(
                      'Hubungi admin untuk mengaktifkan kembali akun Anda.',
                      textAlign: TextAlign.center,
                    )
                  else ...[
                    TextField(
                      controller: _code,
                      enabled: !_loading,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Kode voucher',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                      onSubmitted: (_) => _redeem(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _redeem,
                      child: _loading
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Menggunakan...'),
                              ],
                            )
                          : const Text('Aktifkan voucher'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
