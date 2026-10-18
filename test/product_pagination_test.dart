import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';
import 'package:umkm_manager/features/categories/data/category_repository.dart';
import 'package:umkm_manager/features/products/data/product_repository.dart';
import 'package:umkm_manager/features/products/domain/product.dart';
import 'package:umkm_manager/features/products/presentation/views/products_page.dart';

void main() {
  testWidgets('product search is debounced and requests the next cursor', (
    tester,
  ) async {
    final repository = _ProductPageFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repository),
          categoriesProvider(
            'business-1',
          ).overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: ProductsPage(
            business: Business(
              id: 'business-1',
              name: 'Toko Uji',
              type: BusinessType.retail,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(1));
    expect(find.widgetWithText(ListTile, 'Kopi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Teh');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.requests, hasLength(1));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(repository.requests.last.search, 'Teh');
    expect(find.widgetWithText(ListTile, 'Teh'), findsOneWidget);

    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pumpAndSettle();
    expect(repository.requests.last.cursor, isNotNull);
    expect(find.widgetWithText(ListTile, 'Gula'), findsOneWidget);
  });
}

class _ProductPageFake implements ProductRepository {
  final requests =
      <({String search, String? categoryId, ProductCursor? cursor})>[];

  @override
  Future<ProductPage> getProducts({
    required String businessId,
    String search = '',
    String? categoryId,
    ProductCursor? cursor,
  }) async {
    requests.add((search: search, categoryId: categoryId, cursor: cursor));
    if (cursor != null) return ProductPage(items: [_product('3', 'Gula')]);
    if (search == 'Teh') {
      return ProductPage(
        items: [_product('2', 'Teh')],
        nextCursor: ProductCursor(id: '2', createdAt: DateTime.utc(2026, 1, 2)),
      );
    }
    return ProductPage(
      items: [_product('1', 'Kopi')],
      nextCursor: ProductCursor(id: '1', createdAt: DateTime.utc(2026, 1, 1)),
    );
  }

  Product _product(String id, String name) => Product(
    id: id,
    name: name,
    sku: 'SKU-$id',
    purchasePrice: 1000,
    sellingPrice: 2000,
    stock: 10,
    minimumStock: 1,
    unit: 'pcs',
    isActive: true,
  );

  @override
  Future<void> deactivateProduct({
    required String businessId,
    required String productId,
  }) async {}

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
  }) async {}

  @override
  Future<String> uploadProductImage({
    required String businessId,
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://example.com/product.jpg';
}
