import '../../development_preview/data/development_preview_store.dart';
import '../domain/category.dart';
import 'category_repository.dart';

class MockCategoryRepository implements CategoryRepository {
  MockCategoryRepository(this._store);

  final DevelopmentPreviewStore _store;

  @override
  Future<List<Category>> getCategories(String businessId) async =>
      List.unmodifiable(_store.categoriesFor(businessId));

  @override
  Future<void> createCategory({
    required String businessId,
    required String name,
  }) async {
    _store
        .categoriesFor(businessId)
        .add(
          Category(
            id: 'preview-category-${DateTime.now().microsecondsSinceEpoch}',
            name: name.trim(),
          ),
        );
  }
}
