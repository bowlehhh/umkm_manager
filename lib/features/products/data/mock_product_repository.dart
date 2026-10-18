import 'dart:convert';
import 'dart:typed_data';

import '../../development_preview/data/development_preview_store.dart';
import '../domain/product.dart';
import 'product_repository.dart';

class MockProductRepository implements ProductRepository {
  MockProductRepository(this._store);

  final DevelopmentPreviewStore _store;

  @override
  Future<ProductPage> getProducts({
    required String businessId,
    String search = '',
    String? categoryId,
    ProductCursor? cursor,
  }) async {
    final normalized = search.trim().toLowerCase();
    return ProductPage(
      items: List.unmodifiable(
        _store
            .productsFor(businessId)
            .where((product) => product.isActive)
            .where(
              (product) =>
                  categoryId == null || product.categoryId == categoryId,
            )
            .where(
              (product) =>
                  normalized.isEmpty ||
                  product.name.toLowerCase().contains(normalized) ||
                  product.sku.toLowerCase().contains(normalized),
            ),
      ),
    );
  }

  @override
  Future<void> saveProduct({
    required String businessId,
    Product? existing,
    required String name,
    required String sku,
    String? barcode,
    String? imageUrl,
    String? categoryId,
    required int purchasePrice,
    required int sellingPrice,
    required int stock,
    required int minimumStock,
    required String unit,
  }) async {
    final products = _store.productsFor(businessId);
    final category = _store
        .categoriesFor(businessId)
        .where((item) => item.id == categoryId);
    final categoryName = category.isEmpty ? null : category.first.name;
    final product = Product(
      id:
          existing?.id ??
          'preview-product-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      sku: sku.trim(),
      barcode: _nullIfBlank(barcode),
      imageUrl: _nullIfBlank(imageUrl),
      categoryId: categoryId,
      categoryName: categoryName,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      stock: stock,
      minimumStock: minimumStock,
      unit: unit.trim(),
      isActive: true,
    );
    if (existing == null) {
      products.add(product);
    } else {
      final index = products.indexWhere((item) => item.id == existing.id);
      products[index] = product;
    }
  }

  @override
  Future<String> uploadProductImage({
    required String businessId,
    required Uint8List bytes,
    required String contentType,
  }) async => 'data:$contentType;base64,${base64Encode(bytes)}';

  @override
  Future<void> deactivateProduct({
    required String businessId,
    required String productId,
  }) async {
    final products = _store.productsFor(businessId);
    final index = products.indexWhere((item) => item.id == productId);
    if (index < 0) return;
    final item = products[index];
    products[index] = Product(
      id: item.id,
      name: item.name,
      sku: item.sku,
      barcode: item.barcode,
      imageUrl: item.imageUrl,
      categoryId: item.categoryId,
      categoryName: item.categoryName,
      purchasePrice: item.purchasePrice,
      sellingPrice: item.sellingPrice,
      stock: item.stock,
      minimumStock: item.minimumStock,
      unit: item.unit,
      isActive: false,
    );
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
