import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/product_image.dart';
import '../../../businesses/domain/business.dart';
import '../../../products/data/product_repository.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/controllers/product_controller.dart';

/// Stok memuat seluruh katalog, bukan hanya halaman pertama seperti layar
/// Produk. Barang lama tetap dapat disesuaikan dari sini.
final stockProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  businessId,
) async {
  final repository = ref.watch(productRepositoryProvider);
  final products = <Product>[];
  ProductCursor? cursor;
  do {
    final page = await repository.getProducts(
      businessId: businessId,
      cursor: cursor,
    );
    products.addAll(page.items);
    cursor = page.nextCursor;
  } while (cursor != null);
  return products;
});

/// Persediaan memakai sumber produk yang sama dengan Produk dan Kasir, agar
/// angka stok yang diubah di sini langsung menjadi batas jumlah di kasir.
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key, required this.business});

  final Business business;

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  StockStatus? _filter;

  Future<void> _adjust(Product product) async {
    final controller = TextEditingController(text: product.stock.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Atur stok ${product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Jumlah stok (${product.unit})',
            helperText: 'Stok ini langsung dipakai oleh kasir.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final stock = int.tryParse(controller.text.trim());
              if (stock == null || stock < 0) return;
              Navigator.pop(context, stock);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;

    final error = await ref
        .read(productControllerProvider.notifier)
        .save(
          businessId: widget.business.id,
          businessType: widget.business.type,
          existing: product,
          name: product.name,
          sku: product.sku,
          barcode: product.barcode,
          categoryId: product.categoryId,
          purchasePrice: product.purchasePrice,
          sellingPrice: product.sellingPrice,
          stock: value,
          minimumStock: product.minimumStock,
          unit: product.unit,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.invalidate(productsProvider(widget.business.id));
    ref.invalidate(stockProductsProvider(widget.business.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stok diperbarui. Kasir akan memakai jumlah terbaru.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(stockProductsProvider(widget.business.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () =>
                ref.invalidate(stockProductsProvider(widget.business.id)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Muat ulang stok'),
          ),
        ),
        data: (products) {
          final items = products
              .where((item) => _filter == null || item.stockStatus == _filter)
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Semua',
                      selected: _filter == null,
                      onSelected: () => setState(() => _filter = null),
                    ),
                    _FilterChip(
                      label: 'Menipis',
                      selected: _filter == StockStatus.low,
                      onSelected: () =>
                          setState(() => _filter = StockStatus.low),
                    ),
                    _FilterChip(
                      label: 'Habis',
                      selected: _filter == StockStatus.out,
                      onSelected: () =>
                          setState(() => _filter = StockStatus.out),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('Tidak ada produk pada status stok ini.'),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(
                          stockProductsProvider(widget.business.id),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _StockCard(
                            product: items[index],
                            onAdjust: () => _adjust(items[index]),
                          ),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
  );
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.product, required this.onAdjust});

  final Product product;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (product.stockStatus) {
      StockStatus.safe => ('Stok aman', const Color(0xFF15803D)),
      StockStatus.low => ('Stok menipis', const Color(0xFFD97706)),
      StockStatus.out => ('Stok habis', const Color(0xFFDC2626)),
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          height: 44,
          width: 44,
          child: ProductImage(
            imageUrl: product.imageUrl,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        title: Text(product.name),
        subtitle: Text(
          '$label • ${product.stock} ${product.unit}',
          style: TextStyle(color: color),
        ),
        trailing: TextButton(onPressed: onAdjust, child: const Text('Atur')),
        onTap: onAdjust,
      ),
    );
  }
}
