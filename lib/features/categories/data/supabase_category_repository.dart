import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/category.dart';
import 'category_repository.dart';

class SupabaseCategoryRepository implements CategoryRepository {
  const SupabaseCategoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Category>> getCategories(String businessId) async {
    final data = await _client
        .from('categories')
        .select('id, name')
        .eq('business_id', businessId)
        .order('name');
    return data.map((item) => Category.fromJson(item)).toList(growable: false);
  }

  @override
  Future<void> createCategory({
    required String businessId,
    required String name,
  }) {
    return _client.from('categories').insert({
      'business_id': businessId,
      'name': name.trim(),
    });
  }
}
