import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../businesses/domain/business.dart';
import '../../../products/data/product_repository.dart';
import '../../../products/domain/product.dart';
import '../../../transactions/domain/sales_transaction.dart';
import '../../../transactions/presentation/controllers/checkout_controller.dart';

class CashierPage extends ConsumerStatefulWidget {
  const CashierPage({super.key, required this.business});

  final Business business;

  @override
  ConsumerState<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends ConsumerState<CashierPage> {
  final Map<String, int> _quantities = {};

  Future<void> _openCheckout(List<Product> cart, int total) async {
    final transaction = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CheckoutSheet(
        total: total,
        onPay: (method, amountPaid) async {
          final error = await ref
              .read(checkoutControllerProvider.notifier)
              .checkout(
                businessId: widget.business.id,
                items: cart
                    .map(
                      (product) => CheckoutLine(
                        productId: product.id,
                        quantity: _quantities[product.id]!,
                      ),
                    )
                    .toList(),
                paymentMethod: method,
                amountPaid: amountPaid,
              );
          if (error != null) return error;
          if (mounted) setState(_quantities.clear);
          return null;
        },
      ),
    );
    if (mounted && transaction != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi berhasil disimpan dan stok diperbarui.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(widget.business.id));
    final usesInventory = widget.business.type.usesInventory;
    final itemLabel = widget.business.type.itemLabel.toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Produk belum dapat dimuat.')),
        data: (items) {
          final cart = items
              .where((item) => _quantities.containsKey(item.id))
              .toList();
          final total = cart.fold<int>(
            0,
            (sum, item) => sum + item.sellingPrice * _quantities[item.id]!,
          );
          return Column(
            children: [
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('Belum ada $itemLabel untuk dijual.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _ProductSelector(
                          product: items[index],
                          usesInventory: usesInventory,
                          quantity: _quantities[items[index].id] ?? 0,
                          onAdd: () => setState(() {
                            final product = items[index];
                            final current = _quantities[product.id] ?? 0;
                            if (current < product.stock) {
                              _quantities[product.id] = current + 1;
                            }
                          }),
                          onRemove: () => setState(() {
                            final product = items[index];
                            final current = _quantities[product.id] ?? 0;
                            if (current <= 1) {
                              _quantities.remove(product.id);
                            } else {
                              _quantities[product.id] = current - 1;
                            }
                          }),
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 12,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${cart.length} $itemLabel di keranjang'),
                            Text(
                              CurrencyFormatter.rupiah(total),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: cart.isEmpty
                            ? null
                            : () => _openCheckout(cart, total),
                        child: const Text('Bayar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.total, required this.onPay});

  final int total;
  final Future<String?> Function(CheckoutPaymentMethod method, int amountPaid)
  onPay;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  late final TextEditingController _amountController;
  CheckoutPaymentMethod _method = CheckoutPaymentMethod.cash;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.total.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final amount = int.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nominal pembayaran yang valid.'),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final error = await widget.onPay(_method, amount);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error == null) {
      Navigator.pop(context, 'success');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final change =
        (int.tryParse(
              _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0) -
        widget.total;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pembayaran', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              'Total: ${CurrencyFormatter.rupiah(widget.total)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CheckoutPaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Metode pembayaran'),
              items: CheckoutPaymentMethod.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() {
                      _method = value!;
                      if (_method != CheckoutPaymentMethod.cash) {
                        _amountController.text = widget.total.toString();
                      }
                    }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              enabled: _method == CheckoutPaymentMethod.cash && !_isLoading,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Uang diterima'),
            ),
            if (_method == CheckoutPaymentMethod.cash) ...[
              const SizedBox(height: 8),
              Text(
                'Kembalian: ${CurrencyFormatter.rupiah(change < 0 ? 0 : change)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _pay,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Selesaikan transaksi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSelector extends StatelessWidget {
  const _ProductSelector({
    required this.product,
    required this.usesInventory,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final Product product;
  final bool usesInventory;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(product.name),
      subtitle: Text(
        usesInventory
            ? '${CurrencyFormatter.rupiah(product.sellingPrice)} • stok ${product.stock}'
            : CurrencyFormatter.rupiah(product.sellingPrice),
      ),
      trailing: quantity == 0
          ? IconButton.filled(
              onPressed: usesInventory && product.stock == 0 ? null : onAdd,
              icon: const Icon(Icons.add),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$quantity'),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
    ),
  );
}
