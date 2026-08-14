import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../data/customer_repository.dart';
import '../../domain/customer.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({
    super.key,
    required this.businessId,
    required this.customerId,
    required this.showDebt,
  });
  final String businessId;
  final String customerId;
  final bool showDebt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (businessId: businessId, customerId: customerId);
    final customer = ref.watch(customerProvider(key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pelanggan'),
        actions: customer.maybeWhen(
          data: (_) => [
            IconButton(
              tooltip: 'Edit pelanggan',
              onPressed: () => context.push('/customers/$customerId/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Nonaktifkan pelanggan',
              onPressed: () => _archive(context, ref),
              icon: const Icon(Icons.person_off_outlined),
            ),
          ],
          orElse: () => const [],
        ),
      ),
      body: customer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _Failure(onRetry: () => ref.invalidate(customerProvider(key))),
        data: (value) => _CustomerContent(
          customer: value,
          customerKey: key,
          showDebt: showDebt,
        ),
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan pelanggan?'),
        content: const Text(
          'Pelanggan tidak akan muncul pada daftar baru. Riwayat transaksi tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await ref
          .read(customerRepositoryProvider)
          .archiveCustomer(businessId: businessId, customerId: customerId);
      ref.invalidate(customersProvider(businessId));
      if (context.mounted) {
        context.pop();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pelanggan belum dapat dinonaktifkan.')),
        );
      }
    }
  }
}

class _CustomerContent extends ConsumerWidget {
  const _CustomerContent({
    required this.customer,
    required this.customerKey,
    required this.showDebt,
  });
  final Customer customer;
  final CustomerKey customerKey;
  final bool showDebt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(customerTransactionsProvider(customerKey));
    final debt = showDebt
        ? ref.watch(customerDebtSummaryProvider(customerKey))
        : null;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerProvider(customerKey));
        ref.invalidate(customerTransactionsProvider(customerKey));
        if (showDebt) {
          ref.invalidate(customerDebtSummaryProvider(customerKey));
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    value: customer.phone,
                  ),
                  _ContactRow(
                    icon: Icons.email_outlined,
                    value: customer.email,
                  ),
                  _ContactRow(
                    icon: Icons.location_on_outlined,
                    value: customer.address,
                  ),
                  if (customer.notes?.isNotEmpty == true) ...[
                    const Divider(height: 24),
                    Text(
                      'Catatan',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(customer.notes!),
                  ],
                ],
              ),
            ),
          ),
          if (debt != null) ...[
            const SizedBox(height: 16),
            debt.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (value) => Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Piutang aktif'),
                  subtitle: Text(
                    value.openCount == 0
                        ? 'Tidak ada piutang aktif'
                        : '${value.openCount} tagihan belum lunas',
                  ),
                  trailing: Text(
                    CurrencyFormatter.rupiah(value.remainingAmount),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Riwayat transaksi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          transactions.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Riwayat transaksi belum dapat dimuat.'),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada transaksi untuk pelanggan ini.'),
                    ),
                  )
                : Card(
                    child: Column(
                      children: items
                          .map(
                            (item) => ListTile(
                              leading: const Icon(Icons.receipt_long_outlined),
                              title: Text(item.invoiceNumber),
                              subtitle: Text(
                                DateFormat(
                                  'd MMM y, HH:mm',
                                  'id_ID',
                                ).format(item.createdAt),
                              ),
                              trailing: Text(
                                CurrencyFormatter.rupiah(item.total),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});
  final IconData icon;
  final String? value;
  @override
  Widget build(BuildContext context) => value?.isNotEmpty != true
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(value!)),
            ],
          ),
        );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Coba lagi'),
    ),
  );
}
