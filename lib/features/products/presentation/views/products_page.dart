import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/product_image.dart';
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
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<Product> _products = const [];
  ProductCursor? _nextCursor;
  Object? _error;
  var _isInitialLoading = true;
  var _isLoadingMore = false;
  var _requestVersion = 0;

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

  void _onCategoryChanged(String? categoryId) {
    setState(() => _categoryId = categoryId);
    _loadPage(reset: true);
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
        _error = null;
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
            categoryId: _categoryId,
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
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() => _error = error);
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openForm([Product? product]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ProductFormSheet(
        businessId: widget.business.id,
        businessType: widget.business.type,
        itemLabel: widget.business.type.itemLabel,
        usesInventory: widget.business.type.usesInventory,
        product: product,
      ),
    );
    if (mounted) await _loadPage(reset: true);
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
    } else if (mounted) {
      await _loadPage(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                hintText: 'Cari nama menu atau barang',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: _onSearchChanged,
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
                      onSelected: (_) => _onCategoryChanged(null),
                    ),
                  ),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.name),
                        selected: _categoryId == item.id,
                        onSelected: (_) => _onCategoryChanged(item.id),
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
            child: _isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _products.isEmpty
                ? _FailureState(onRetry: () => _loadPage(reset: true))
                : _products.isEmpty
                ? _EmptyProducts(
                    itemLabel: widget.business.type.itemLabel,
                    onAdd: () => _openForm(),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadPage(reset: true),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount:
                          _products.length + (_nextCursor != null ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                                    child: const Text('Muat lebih banyak'),
                                  ),
                          );
                        }
                        final product = _products[index];
                        return _ProductCard(
                          product: product,
                          usesInventory: widget.business.type.usesInventory,
                          onEdit: () => _openForm(product),
                          onDeactivate: () => _deactivate(product),
                        );
                      },
                    ),
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
        leading: SizedBox(
          height: 44,
          width: 44,
          child: ProductImage(
            imageUrl: product.imageUrl,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        title: Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(CurrencyFormatter.rupiah(product.sellingPrice)),
            if (product.categoryName != null) ...[
              const SizedBox(height: 4),
              Text('Kategori: ${product.categoryName}'),
            ],
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
