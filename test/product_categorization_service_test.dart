import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';
import 'package:umkm_manager/features/categories/domain/category.dart';
import 'package:umkm_manager/features/products/domain/product_categorization_service.dart';

void main() {
  const service = ProductCategorizationService();

  test('nama menu dikenal memakai aturan lokal tanpa AI', () {
    final result = service.suggest(
      businessType: BusinessType.culinary,
      itemName: 'Es teh manis',
      knownCategories: const [],
    );
    expect(result.name, 'Minuman');
    expect(result.source, ProductCategorySource.rule);
  });

  test('kategori yang sudah ada dipakai dalam konteks usaha sendiri', () {
    final result = service.suggest(
      businessType: BusinessType.culinary,
      itemName: 'Kopi',
      knownCategories: const [Category(id: 'drink', name: 'Minuman')],
    );
    expect(result.name, 'Minuman');
  });

  test('nama yang belum jelas aman masuk kategori Lainnya', () {
    final result = service.suggest(
      businessType: BusinessType.other,
      itemName: 'Paket spesial',
      knownCategories: const [],
    );
    expect(result.name, 'Lainnya');
    expect(result.source, ProductCategorySource.fallback);
  });
}
