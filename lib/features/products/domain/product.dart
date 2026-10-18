class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    required this.minimumStock,
    required this.unit,
    required this.isActive,
    this.categoryId,
    this.categoryName,
    this.barcode,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: category is Map<String, dynamic>
          ? category['name'] as String?
          : null,
      barcode: json['barcode'] as String?,
      imageUrl: json['image_url'] as String?,
      purchasePrice: json['purchase_price'] as int,
      sellingPrice: json['selling_price'] as int,
      stock: json['stock'] as int,
      minimumStock: json['minimum_stock'] as int,
      unit: json['unit'] as String,
      isActive: json['is_active'] as bool,
    );
  }

  final String id;
  final String name;
  final String sku;
  final String? categoryId;
  final String? categoryName;
  final String? barcode;
  final String? imageUrl;
  final int purchasePrice;
  final int sellingPrice;
  final int stock;
  final int minimumStock;
  final String unit;
  final bool isActive;

  StockStatus get stockStatus {
    if (stock == 0) return StockStatus.out;
    if (stock <= minimumStock) return StockStatus.low;
    return StockStatus.safe;
  }
}

enum StockStatus { safe, low, out }

class ProductCursor {
  const ProductCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;
}

class ProductPage {
  const ProductPage({required this.items, this.nextCursor});

  final List<Product> items;
  final ProductCursor? nextCursor;

  bool get hasMore => nextCursor != null;
}
