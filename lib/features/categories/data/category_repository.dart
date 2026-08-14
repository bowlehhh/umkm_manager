import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../development_preview/data/development_preview_store.dart';
import '../domain/category.dart';
import 'mock_category_repository.dart';
import 'supabase_category_repository.dart';

abstract interface class CategoryRepository {
  Future<List<Category>> getCategories(String businessId);

  Future<void> createCategory({
    required String businessId,
    required String name,
  });
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  if (ref.watch(appConfigProvider).isDevelopmentPreview) {
    return MockCategoryRepository(ref.watch(developmentPreviewStoreProvider));
  }
  return SupabaseCategoryRepository(ref.watch(supabaseClientProvider));
});

final categoriesProvider = FutureProvider.family<List<Category>, String>(
  (ref, businessId) =>
      ref.watch(categoryRepositoryProvider).getCategories(businessId),
);
