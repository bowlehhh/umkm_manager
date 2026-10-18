import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_mapper.dart';
import '../../../businesses/domain/business.dart';
import '../../../categories/data/category_repository.dart';
import '../../data/product_repository.dart';
import '../../domain/product.dart';
import '../../domain/product_categorization_service.dart';

final productControllerProvider =
    NotifierProvider<ProductController, AsyncValue<void>>(
      ProductController.new,
    );

class ProductController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> save({
    required String businessId,
    required BusinessType businessType,
    Product? existing,
    required String name,
    required String sku,
    String? barcode,
    Uint8List? imageBytes,
    String? imageContentType,
    String? categoryId,
    required int purchasePrice,
    required int sellingPrice,
    required int stock,
    required int minimumStock,
    required String unit,
  }) {
    return _run(() async {
      final resolvedCategoryId =
          categoryId ??
          await _automaticCategory(
            businessId: businessId,
            businessType: businessType,
            itemName: name,
          );
      final repository = ref.read(productRepositoryProvider);
      final imageUrl = imageBytes == null
          ? existing?.imageUrl
          : await repository.uploadProductImage(
              businessId: businessId,
              bytes: imageBytes,
              contentType: imageContentType ?? 'image/jpeg',
            );
      await repository.saveProduct(
        businessId: businessId,
        existing: existing,
        name: name,
        sku: sku,
        barcode: barcode,
        imageUrl: imageUrl,
        categoryId: resolvedCategoryId,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        stock: stock,
        minimumStock: minimumStock,
        unit: unit,
      );
      ref.invalidate(productsProvider(businessId));
    });
  }

  Future<String?> _automaticCategory({
    required String businessId,
    required BusinessType businessType,
    required String itemName,
  }) async {
    try {
      final repository = ref.read(categoryRepositoryProvider);
      var categories = await repository.getCategories(businessId);
      final suggestion = const ProductCategorizationService().suggest(
        businessType: businessType,
        itemName: itemName,
        knownCategories: categories,
      );
      final match = categories
          .where(
            (category) =>
                category.name.toLowerCase() == suggestion.name.toLowerCase(),
          )
          .firstOrNull;
      if (match != null) return match.id;
      await repository.createCategory(
        businessId: businessId,
        name: suggestion.name,
      );
      categories = await repository.getCategories(businessId);
      return categories
          .where(
            (category) =>
                category.name.toLowerCase() == suggestion.name.toLowerCase(),
          )
          .firstOrNull
          ?.id;
    } catch (_) {
      // Kategori tidak boleh menghalangi menu disimpan. Produk tetap valid
      // karena category_id memang nullable pada schema yang sudah ada.
      return null;
    }
  }

  Future<String?> deactivate({
    required String businessId,
    required String productId,
  }) {
    return _run(() async {
      await ref
          .read(productRepositoryProvider)
          .deactivateProduct(businessId: businessId, productId: productId);
      ref.invalidate(productsProvider(businessId));
    });
  }

  Future<String?> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AppErrorMapper.message(error);
    }
  }
}
