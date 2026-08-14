import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../businesses/domain/business.dart';
import '../../../categories/data/category_repository.dart';
import '../../../categories/presentation/views/category_manager_sheet.dart';
import '../../data/product_repository.dart';
import '../../domain/product.dart';
import '../controllers/product_controller.dart';
import 'product_form_sheet.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key, required this.business});

  final Business business;

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String _query = '';
  String? _categoryId;

  void _openForm([Product? product]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductFormSheet(
        businessId: widget.business.id,
        itemLabel: widget.business.type.itemLabel,
        usesInventory: widget.business.type.usesInventory,
        product: product,
      ),
    );
  }

  Future<void> _deactivate(Product product) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Nonaktifkan ${widget.business.type.itemLabel.toLowerCase()}?',
        ),
        content: Text('${product.name} tidak akan muncul di kasir.'),
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
    if (accepted != true || !mounted) return;
    final error = await ref
        .read(productControllerProvider.notifier)
        .deactivate(businessId: widget.business.id, productId: product.id);
    if (mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(widget.business.id));
    final categories = ref.watch(categoriesProvider(widget.business.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.business.type.itemLabel),
        actions: [
          IconButton(
            tooltip: 'Kelola kategori',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  CategoryManagerSheet(businessId: widget.business.id),
            ),
            icon: const Icon(Icons.category_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text('Tambah ${widget.business.type.itemLabel.toLowerCase()}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama atau SKU produk',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
            ),
          ),
          categories.maybeWhen(
            data: (items) => SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Semua'),
                      selected: _categoryId == null,
                      onSelected: (_) => setState(() => _categoryId = null),
                    ),
                  ),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.name),
                        selected: _categoryId == item.id,
                        onSelected: (_) =>
                            setState(() => _categoryId = item.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            orElse: SizedBox.shrink,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _FailureState(
                onRetry: () =>
                    ref.invalidate(productsProvider(widget.business.id)),
              ),
              data: (items) {
                final filtered = items.where((product) {
                  final matchesQuery =
                      _query.isEmpty ||
                      product.name.toLowerCase().contains(_query) ||
                      product.sku.toLowerCase().contains(_query);
                  return matchesQuery &&
                      (_categoryId == null ||
                          product.categoryId == _categoryId);
                }).toList();
                if (filtered.isEmpty) {
                  return _EmptyProducts(
                    itemLabel: widget.business.type.itemLabel,
                    onAdd: () => _openForm(),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(productsProvider(widget.business.id)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ProductCard(
                      product: filtered[index],
                      usesInventory: widget.business.type.usesInventory,
                      onEdit: () => _openForm(filtered[index]),
                      onDeactivate: () => _deactivate(filtered[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.usesInventory,
    required this.onEdit,
    required this.onDeactivate,
  });

  final Product product;
  final bool usesInventory;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (product.stockStatus) {
      StockStatus.safe => ('Stok aman', AppColors.success),
      StockStatus.low => ('Stok menipis', AppColors.warning),
      StockStatus.out => ('Stok habis', AppColors.danger),
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${CurrencyFormatter.rupiah(product.sellingPrice)} • ${product.sku}',
            ),
            if (usesInventory) ...[
              const SizedBox(height: 4),
              Text(
                '$label • ${product.stock} ${product.unit}',
                style: TextStyle(color: color),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'deactivate') onDeactivate();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Ubah')),
            PopupMenuItem(value: 'deactivate', child: Text('Nonaktifkan')),
          ],
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.itemLabel, required this.onAdd});

  final String itemLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 52),
          const SizedBox(height: 16),
          Text(
            'Belum ada ${itemLabel.toLowerCase()}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan ${itemLabel.toLowerCase()} pertama untuk mulai berjualan.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text('Tambah $itemLabel'),
          ),
        ],
      ),
    ),
  );
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Muat ulang produk'),
    ),
  );
}
