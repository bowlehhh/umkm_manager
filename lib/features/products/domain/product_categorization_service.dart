import '../../businesses/domain/business.dart';
import '../../categories/domain/category.dart';

enum ProductCategorySource { rule, existingMapping, fallback }

class ProductCategorySuggestion {
  const ProductCategorySuggestion({
    required this.name,
    required this.confidence,
    required this.source,
  });

  final String name;
  final double confidence;
  final ProductCategorySource source;
}

/// Penentuan kategori lokal yang tidak memakai kuota AI. Nama kategori tetap
/// scoped pada usaha pemilik karena daftar [knownCategories] berasal dari sana.
class ProductCategorizationService {
  const ProductCategorizationService();

  ProductCategorySuggestion suggest({
    required BusinessType businessType,
    required String itemName,
    required List<Category> knownCategories,
  }) {
    final normalized = _normalize(itemName);
    for (final category in knownCategories) {
      if (_normalize(category.name) == normalized) {
        return ProductCategorySuggestion(
          name: category.name,
          confidence: 1,
          source: ProductCategorySource.existingMapping,
        );
      }
    }
    final name = _ruleCategory(businessType, normalized);
    if (name != null) {
      final existing = knownCategories
          .where((category) => _normalize(category.name) == _normalize(name))
          .firstOrNull;
      return ProductCategorySuggestion(
        name: existing?.name ?? name,
        confidence: 0.92,
        source: ProductCategorySource.rule,
      );
    }
    return const ProductCategorySuggestion(
      name: 'Lainnya',
      confidence: 0,
      source: ProductCategorySource.fallback,
    );
  }

  String? _ruleCategory(BusinessType type, String name) {
    bool has(Iterable<String> words) => words.any(name.contains);
    if (type == BusinessType.culinary) {
      if (has(['es ', 'teh', 'kopi', 'jus', 'susu', 'minum'])) return 'Minuman';
      if (has(['nasi', 'mie', 'ayam', 'sate', 'roti', 'makan'])) {
        return 'Makanan';
      }
    }
    if (has(['oli', 'pelumas', 'grease'])) return 'Pelumas';
    if (has(['ban', 'kampas', 'busi', 'sparepart'])) return 'Sparepart';
    if (type == BusinessType.service) return 'Layanan';
    return null;
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
