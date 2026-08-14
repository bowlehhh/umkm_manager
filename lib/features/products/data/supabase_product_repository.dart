import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/product.dart';
import 'product_repository.dart';

class SupabaseProductRepository implements ProductRepository {
  const SupabaseProductRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Product>> getProducts(String businessId) async {
    final data = await _client
        .from('products')
        .select('*, category:categories(name)')
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name');
    return data.map((item) => Product.fromJson(item)).toList(growable: false);
  }

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
    final values = {
      'business_id': businessId,
      'name': name.trim(),
      'sku': sku.trim(),
      'barcode': _nullIfBlank(barcode),
      'category_id': categoryId,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'stock': stock,
      'minimum_stock': minimumStock,
      'unit': unit.trim(),
    };
    if (existing == null) {
      await _client.from('products').insert(values);
    } else {
      await _client
          .from('products')
          .update(values)
          .eq('id', existing.id)
          .eq('business_id', businessId);
    }
  }

  @override
  Future<void> deactivateProduct({
    required String businessId,
    required String productId,
  }) {
    return _client
        .from('products')
        .update({'is_active': false})
        .eq('id', productId)
        .eq('business_id', businessId);
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
