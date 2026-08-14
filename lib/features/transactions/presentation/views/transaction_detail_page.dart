import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../data/transaction_repository.dart';
import '../../domain/sales_transaction.dart';

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({
    super.key,
    required this.businessId,
    required this.transactionId,
  });

  final String businessId;
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (businessId: businessId, transactionId: transactionId);
    final transaction = ref.watch(transactionDetailProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Invoice')),
      body: transaction.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(transactionDetailProvider(key)),
            child: const Text('Coba lagi'),
          ),
        ),
        data: (value) => _InvoiceContent(transaction: value),
      ),
    );
  }
}

class _InvoiceContent extends StatelessWidget {
  const _InvoiceContent({required this.transaction});

  final SalesTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat(
      'EEEE, d MMMM y • HH:mm',
      'id_ID',
    ).format(transaction.createdAt);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  'Transaksi berhasil',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.invoiceNumber,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Rincian belanja', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: transaction.items.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Rincian item tidak tersedia.'),
                    ),
                  ]
                : transaction.items
                      .map(
                        (item) => ListTile(
                          title: Text(item.productName),
                          subtitle: Text(
                            '${item.quantity} × ${CurrencyFormatter.rupiah(item.sellingPrice)}',
                          ),
                          trailing: Text(
                            CurrencyFormatter.rupiah(item.subtotal),
                          ),
                        ),
                      )
                      .toList(),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _AmountRow(
                  label: 'Subtotal',
                  amount: transaction.subtotal ?? transaction.total,
                ),
                if (transaction.discountAmount > 0)
                  _AmountRow(
                    label: 'Diskon',
                    amount: -transaction.discountAmount,
                  ),
                const Divider(height: 24),
                _AmountRow(
                  label: 'Total',
                  amount: transaction.total,
                  prominent: true,
                ),
                const SizedBox(height: 10),
                _TextRow(
                  label: 'Metode pembayaran',
                  value: _paymentLabel(transaction.paymentMethod),
                ),
                if (transaction.amountPaid != null)
                  _AmountRow(
                    label: 'Uang diterima',
                    amount: transaction.amountPaid!,
                  ),
                if (transaction.changeAmount > 0)
                  _AmountRow(
                    label: 'Kembalian',
                    amount: transaction.changeAmount,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _paymentLabel(String value) => switch (value) {
    'CASH' => 'Tunai',
    'TRANSFER' => 'Transfer',
    'QRIS' => 'QRIS',
    'DEBT' => 'Bon',
    _ => value,
  };
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.prominent = false,
  });

  final String label;
  final int amount;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: prominent ? Theme.of(context).textTheme.titleMedium : null,
        ),
        Text(
          CurrencyFormatter.rupiah(amount),
          style: prominent ? Theme.of(context).textTheme.titleMedium : null,
        ),
      ],
    ),
  );
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    ),
  );
}
