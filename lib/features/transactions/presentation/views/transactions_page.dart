import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../businesses/domain/business.dart';
import '../../data/transaction_repository.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key, required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider(business.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(transactionsProvider(business.id)),
            child: const Text('Coba lagi'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Belum ada transaksi hari ini'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final transaction = items[index];
                  final time =
                      '${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}';
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () =>
                          context.push('/transactions/${transaction.id}'),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt_long_outlined),
                        ),
                        title: Text(transaction.invoiceNumber),
                        subtitle: Text('${transaction.paymentMethod} • $time'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CurrencyFormatter.rupiah(transaction.total),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
