import '../../development_preview/data/development_preview_store.dart';
import '../domain/product.dart';
import 'product_repository.dart';

class MockProductRepository implements ProductRepository {
  MockProductRepository(this._store);

  final DevelopmentPreviewStore _store;

  @override
  Future<List<Product>> getProducts(String businessId) async =>
      List.unmodifiable(
        _store.productsFor(businessId).where((product) => product.isActive),
      );

  @override
  Future<void> saveProduct({
    required String businessId,
    Product? existing,
    required String name,
    required String sku,
    String? barcode,
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
