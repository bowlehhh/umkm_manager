import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/product_image.dart';
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
  final Map<String, Product> _selectedProducts = {};
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<Product> _products = const [];
  ProductCursor? _nextCursor;
  var _isInitialLoading = true;
  var _isLoadingMore = false;
  var _requestVersion = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future<void>.microtask(() => _loadPage(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240) _loadPage();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadPage(reset: true),
    );
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (!reset &&
        (_isInitialLoading || _isLoadingMore || _nextCursor == null)) {
      return;
    }
    final requestVersion = ++_requestVersion;
    final cursor = reset ? null : _nextCursor;
    setState(() {
      if (reset) {
        _isInitialLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });
    try {
      final page = await ref
          .read(productRepositoryProvider)
          .getProducts(
            businessId: widget.business.id,
            search: _query,
            cursor: cursor,
          );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _products = reset
            ? page.items
            : [
                ..._products,
                ...page.items.where(
                  (item) =>
                      !_products.any((existing) => existing.id == item.id),
                ),
              ];
        _nextCursor = page.nextCursor;
      });
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

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
          if (mounted) {
            setState(() {
              _quantities.clear();
              _selectedProducts.clear();
            });
            await _loadPage(reset: true);
          }
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
    final usesInventory = widget.business.type.usesInventory;
    final itemLabel = widget.business.type.itemLabel.toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                final cart = _quantities.keys
                    .map((id) => _selectedProducts[id])
                    .whereType<Product>()
                    .toList(growable: false);
                final total = cart.fold<int>(
                  0,
                  (sum, item) =>
                      sum + item.sellingPrice * _quantities[item.id]!,
                );
                final cartItemCount = _quantities.values.fold<int>(
                  0,
                  (sum, quantity) => sum + quantity,
                );
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Cari nama atau SKU produk',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    Expanded(
                      child: _products.isEmpty
                          ? Center(
                              child: Text('Belum ada $itemLabel untuk dijual.'),
                            )
                          : GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 220,
                                    mainAxisExtent: 238,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount:
                                  _products.length +
                                  (_nextCursor != null ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _products.length) {
                                  return Center(
                                    child: _isLoadingMore
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(),
                                          )
                                        : TextButton(
                                            onPressed: _loadPage,
                                            child: const Text(
                                              'Muat lebih banyak',
                                            ),
                                          ),
                                  );
                                }
                                final product = _products[index];
                                return _ProductSelector(
                                  product: product,
                                  usesInventory: usesInventory,
                                  quantity: _quantities[product.id] ?? 0,
                                  onAdd: () => setState(() {
                                    final current =
                                        _quantities[product.id] ?? 0;
                                    if (!usesInventory ||
                                        current < product.stock) {
                                      _quantities[product.id] = current + 1;
                                      _selectedProducts[product.id] = product;
                                    }
                                  }),
                                  onRemove: () => setState(() {
                                    final current =
                                        _quantities[product.id] ?? 0;
                                    if (current <= 1) {
                                      _quantities.remove(product.id);
                                      _selectedProducts.remove(product.id);
                                    } else {
                                      _quantities[product.id] = current - 1;
                                    }
                                  }),
                                );
                              },
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
                                  Text(
                                    '$cartItemCount $itemLabel di keranjang',
                                  ),
                                  Text(
                                    CurrencyFormatter.rupiah(total),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
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
  Widget build(BuildContext context) {
    final isOutOfStock = usesInventory && product.stock == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: isOutOfStock ? null : onAdd,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.expand(
                  child: ProductImage(
                    imageUrl: product.imageUrl,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.rupiah(product.sellingPrice),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: quantity == 0
                  ? FilledButton.icon(
                      onPressed: isOutOfStock ? null : onAdd,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(isOutOfStock ? 'Habis' : 'Tambah'),
                    )
                  : Row(
                      children: [
                        IconButton(
                          onPressed: onRemove,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: Text(
                            '$quantity di keranjang',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: isOutOfStock ? null : onAdd,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
