import '../../development_preview/data/development_preview_store.dart';
import '../../products/domain/product.dart';
import '../domain/sales_transaction.dart';
import 'transaction_repository.dart';

class MockTransactionRepository implements TransactionRepository {
  MockTransactionRepository(this._store);

  final DevelopmentPreviewStore _store;
  final Map<String, SalesTransaction> _completedRequests = {};

  @override
  Future<TransactionPage> getTransactions({
    required String businessId,
    TransactionCursor? cursor,
  }) async => TransactionPage(
    items: List.unmodifiable(_store.transactionsFor(businessId).reversed),
  );

  @override
  Future<SalesTransaction> getTransactionDetail({
    required String businessId,
    required String transactionId,
  }) async {
    return _store
        .transactionsFor(businessId)
        .firstWhere((item) => item.id == transactionId);
  }

  @override
  Future<SalesTransaction> checkout({
    required String businessId,
    required String requestId,
    required List<CheckoutLine> items,
    required CheckoutPaymentMethod paymentMethod,
    required int amountPaid,
    String? customerId,
    int discountAmount = 0,
  }) async {
    final completed = _completedRequests[requestId];
    if (completed != null) return completed;
    if (items.isEmpty) throw StateError('Keranjang belanja kosong.');
    var subtotal = 0;
    final products = _store.productsFor(businessId);
    final usesInventory = _store.businesses
        .firstWhere((business) => business.id == businessId)
        .type
        .usesInventory;
    for (final line in items) {
      final product = products
          .where((item) => item.id == line.productId)
          .firstOrNull;
      if (product == null || !product.isActive) {
        throw StateError('Produk tidak tersedia.');
      }
      if (line.quantity <= 0 ||
          (usesInventory && line.quantity > product.stock)) {
        throw StateError('Stok ${product.name} tidak mencukupi.');
      }
      subtotal += product.sellingPrice * line.quantity;
    }
    final total = subtotal - discountAmount;
    if (total < 0) throw StateError('Diskon tidak valid.');
    if (paymentMethod == CheckoutPaymentMethod.cash && amountPaid < total) {
      throw StateError('Uang tunai kurang dari total transaksi.');
    }
    if (usesInventory) {
      for (final line in items) {
        final index = products.indexWhere((item) => item.id == line.productId);
        products[index] = _withStock(
          products[index],
          products[index].stock - line.quantity,
        );
      }
    }
    final now = DateTime.now();
    final transaction = SalesTransaction(
      id: 'preview-transaction-${now.microsecondsSinceEpoch}',
      invoiceNumber:
          'PRV-${now.millisecondsSinceEpoch.toString().substring(6)}',
      total: total,
      paymentMethod: paymentMethod.dbValue,
      createdAt: now,
      subtotal: subtotal,
      amountPaid: amountPaid,
      changeAmount: paymentMethod == CheckoutPaymentMethod.cash
          ? amountPaid - total
          : 0,
      paymentStatus: 'PAID',
      items: items
          .map((line) {
            final product = products.firstWhere(
              (item) => item.id == line.productId,
            );
            return TransactionLine(
              productName: product.name,
              quantity: line.quantity,
              sellingPrice: product.sellingPrice,
              subtotal: product.sellingPrice * line.quantity,
            );
          })
          .toList(growable: false),
    );
    _store.transactionsFor(businessId).add(transaction);
    _completedRequests[requestId] = transaction;
    return transaction;
  }

  Product _withStock(Product product, int stock) => Product(
    id: product.id,
    name: product.name,
    sku: product.sku,
    barcode: product.barcode,
    imageUrl: product.imageUrl,
    categoryId: product.categoryId,
    categoryName: product.categoryName,
    purchasePrice: product.purchasePrice,
    sellingPrice: product.sellingPrice,
    stock: stock,
    minimumStock: product.minimumStock,
    unit: product.unit,
    isActive: product.isActive,
  );
}
