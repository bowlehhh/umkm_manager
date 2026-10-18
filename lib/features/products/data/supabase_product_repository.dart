import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/product.dart';
import 'product_repository.dart';

class SupabaseProductRepository implements ProductRepository {
  const SupabaseProductRepository(this._client);

  final SupabaseClient _client;

  static const _pageSize = 30;
  static const _imageBucket = 'product-images';
  static const _listColumns =
      'id, name, sku, category_id, barcode, image_url, purchase_price, selling_price, stock, minimum_stock, unit, is_active, created_at, category:categories(name)';

  @override
  Future<ProductPage> getProducts({
    required String businessId,
    String search = '',
    String? categoryId,
    ProductCursor? cursor,
  }) async {
    var request = _client
        .from('products')
        .select(_listColumns)
        .eq('business_id', businessId)
        .eq('is_active', true);
    if (categoryId != null) request = request.eq('category_id', categoryId);
    final normalizedSearch = _normalizeSearch(search);
    if (normalizedSearch.isNotEmpty) {
      request = request.ilike('search_text', '%$normalizedSearch%');
    }
    if (cursor != null) {
      final timestamp = cursor.createdAt.toUtc().toIso8601String();
      request = request.or(
        'created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.${cursor.id})',
      );
    }
    final data = await request
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(_pageSize + 1);
    final hasMore = data.length > _pageSize;
    final items = data.take(_pageSize).toList(growable: false);
    final last = items.isEmpty ? null : items.last;
    return ProductPage(
      items: items.map(Product.fromJson).toList(growable: false),
      nextCursor: hasMore && last != null
          ? ProductCursor(
              createdAt: DateTime.parse(last['created_at'] as String),
              id: last['id'] as String,
            )
          : null,
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
    final values = {
      'business_id': businessId,
      'name': name.trim(),
      'sku': sku.trim(),
      'barcode': _nullIfBlank(barcode),
      'image_url': _nullIfBlank(imageUrl),
      'category_id': categoryId,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'minimum_stock': minimumStock,
      'unit': unit.trim(),
    };
    if (existing == null) {
      final created = await _client
          .from('products')
          .insert({...values, 'stock': 0})
          .select('id')
          .single();
      if (stock > 0) {
        await _adjustStock(
          businessId: businessId,
          productId: created['id'] as String,
          balance: stock,
          reason: 'Saldo awal produk',
        );
      }
    } else {
      await _client
          .from('products')
          .update(values)
          .eq('id', existing.id)
          .eq('business_id', businessId);
      if (existing.stock != stock) {
        await _adjustStock(
          businessId: businessId,
          productId: existing.id,
          balance: stock,
          reason: 'Koreksi stok dari formulir produk',
        );
      }
    }
  }

  Future<void> _adjustStock({
    required String businessId,
    required String productId,
    required int balance,
    required String reason,
  }) => _client.rpc(
    'adjust_stock',
    params: {
      'p_business_id': businessId,
      'p_product_id': productId,
      'p_new_balance': balance,
      'p_reason': reason,
      'p_request_id': const Uuid().v4(),
    },
  );

  @override
  Future<String> uploadProductImage({
    required String businessId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        '$businessId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final storage = _client.storage.from(_imageBucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    return storage.getPublicUrl(path);
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

  String _normalizeSearch(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 @+._-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
