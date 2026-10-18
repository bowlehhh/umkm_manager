import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../entitlements/data/entitlement_service.dart';
import '../data/subscription_repository.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});
  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  late Future<
    (
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>,
      Map<String, dynamic>,
    )
  >
  _data = _load();
  Future<
    (
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>,
      Map<String, dynamic>,
    )
  >
  _load() async {
    final repository = ref.read(subscriptionRepositoryProvider);
    return (
      await repository.plans(),
      await repository.invoices(),
      await repository.instructions(),
    );
  }

  void _refresh() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Langganan AI')),
    body: FutureBuilder(
      future: _data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (plans, invoices, instructions) = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder(
              future: ref
                  .read(entitlementServiceProvider)
                  .getCurrentEntitlement(),
              builder: (context, access) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    access.hasData && access.data!.isActive
                        ? 'Paket ${access.data!.planKey ?? '-'} aktif • sisa ${access.data!.remainingAiQuota} dari ${access.data!.aiQuota} kuota AI'
                        : 'Tidak ada paket AI aktif. Data usaha tetap dapat digunakan.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Pilih paket bulanan. Tidak ada perpanjangan otomatis.'),
            ...plans.map(
              (plan) => Card(
                child: ListTile(
                  title: Text(plan['label'] as String),
                  subtitle: Text(
                    '${plan['ai_quota']} konfigurasi AI per periode',
                  ),
                  trailing: Text(
                    CurrencyFormatter.rupiah(plan['monthly_price'] as int),
                  ),
                  onTap: () async {
                    await ref
                        .read(subscriptionRepositoryProvider)
                        .createInvoice(plan['key'] as String);
                    _refresh();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Instruksi pembayaran',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(instructions['instructions'] as String? ?? 'Hubungi admin.'),
            const SizedBox(height: 16),
            Text('Tagihan', style: Theme.of(context).textTheme.titleMedium),
            if (invoices.isEmpty) const Text('Belum ada tagihan.'),
            ...invoices.map(
              (invoice) => Card(
                child: ListTile(
                  title: Text(invoice['invoice_number'] as String),
                  subtitle: Text(
                    '${invoice['plan_label_snapshot']} • ${invoice['status']} • kuota ${invoice['quota_snapshot']}',
                  ),
                  trailing: Text(
                    CurrencyFormatter.rupiah(invoice['price_snapshot'] as int),
                  ),
                  onTap:
                      invoice['status'] == 'UNPAID' ||
                          invoice['status'] == 'REJECTED'
                      ? () => _submit(invoice['id'] as String)
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _submit(String invoiceId) async {
    final payer = TextEditingController();
    final reference = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajukan verifikasi pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: payer,
              decoration: const InputDecoration(labelText: 'Nama pengirim'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Referensi (opsional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, payer.text.trim().length >= 2),
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await ref
          .read(subscriptionRepositoryProvider)
          .submitPayment(
            invoiceId: invoiceId,
            payerName: payer.text,
            reference: reference.text,
          );
      _refresh();
    }
    payer.dispose();
    reference.dispose();
  }
}
