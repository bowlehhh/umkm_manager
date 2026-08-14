import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_mapper.dart';
import '../../data/product_repository.dart';
import '../../domain/product.dart';

final productControllerProvider =
    NotifierProvider<ProductController, AsyncValue<void>>(
      ProductController.new,
    );

class ProductController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> save({
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
  }) {
    return _run(() async {
      await ref
          .read(productRepositoryProvider)
          .saveProduct(
            businessId: businessId,
            existing: existing,
            name: name,
            sku: sku,
            barcode: barcode,
            categoryId: categoryId,
            purchasePrice: purchasePrice,
            sellingPrice: sellingPrice,
            stock: stock,
            minimumStock: minimumStock,
            unit: unit,
          );
      ref.invalidate(productsProvider(businessId));
    });
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
