import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../development_preview/data/development_preview_store.dart';
import '../domain/product.dart';
import 'mock_product_repository.dart';
import 'supabase_product_repository.dart';

abstract interface class ProductRepository {
  Future<ProductPage> getProducts({
    required String businessId,
    String search,
    String? categoryId,
    ProductCursor? cursor,
  });

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
  });

  Future<String> uploadProductImage({
    required String businessId,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> deactivateProduct({
    required String businessId,
    required String productId,
  });
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  if (ref.watch(appConfigProvider).isDevelopmentPreview) {
    return MockProductRepository(ref.watch(developmentPreviewStoreProvider));
  }
  return SupabaseProductRepository(ref.watch(supabaseClientProvider));
});

final productsProvider = FutureProvider.family<ProductPage, String>(
  (ref, businessId) =>
      ref.watch(productRepositoryProvider).getProducts(businessId: businessId),
);
