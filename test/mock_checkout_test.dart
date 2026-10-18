import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';
import 'package:umkm_manager/features/development_preview/data/development_preview_store.dart';
import 'package:umkm_manager/features/products/domain/product.dart';
import 'package:umkm_manager/features/transactions/data/mock_transaction_repository.dart';
import 'package:umkm_manager/features/transactions/domain/sales_transaction.dart';

void main() {
  test(
    'checkout menu kuliner menyimpan transaksi tanpa mengurangi stok',
    () async {
      final store = DevelopmentPreviewStore();
      final repository = MockTransactionRepository(store);
      final initialStock = store.products.first.stock;
      final initialTransactions = store.transactions.length;

      final transaction = await repository.checkout(
        businessId: store.business.id,
        requestId: 'culinary-checkout-1',
        items: [CheckoutLine(productId: store.products.first.id, quantity: 2)],
        paymentMethod: CheckoutPaymentMethod.cash,
        amountPaid: 50000,
      );

      expect(transaction.total, 36000);
      expect(store.products.first.stock, initialStock);
      expect(store.transactions.length, initialTransactions + 1);
    },
  );

  test('checkout layanan tidak memerlukan atau mengurangi stok', () async {
    final store = DevelopmentPreviewStore();
    const serviceBusiness = Business(
      id: 'preview-service',
      name: 'Salon Rapi',
      type: BusinessType.service,
      isActive: true,
    );
    store.businesses.add(serviceBusiness);
    store.activateBusiness(serviceBusiness.id);
    store
        .productsFor(serviceBusiness.id)
        .add(
          const Product(
            id: 'haircut',
            name: 'Potong Rambut',
            sku: 'SRV-001',
            purchasePrice: 0,
            sellingPrice: 30000,
            stock: 0,
            minimumStock: 0,
            unit: 'sesi',
            isActive: true,
          ),
        );
    final repository = MockTransactionRepository(store);

    final transaction = await repository.checkout(
      businessId: serviceBusiness.id,
      requestId: 'service-checkout-1',
      items: const [CheckoutLine(productId: 'haircut', quantity: 1)],
      paymentMethod: CheckoutPaymentMethod.cash,
      amountPaid: 30000,
    );

    expect(transaction.total, 30000);
    expect(store.productsFor(serviceBusiness.id).single.stock, 0);
  });

  test(
    'retry request checkout yang sama tidak menggandakan transaksi',
    () async {
      final store = DevelopmentPreviewStore();
      final repository = MockTransactionRepository(store);
      final before = store.transactions.length;
      final line = CheckoutLine(
        productId: store.products.first.id,
        quantity: 1,
      );

      final first = await repository.checkout(
        businessId: store.business.id,
        requestId: 'stable-request-id',
        items: [line],
        paymentMethod: CheckoutPaymentMethod.cash,
        amountPaid: 50000,
      );
      final retried = await repository.checkout(
        businessId: store.business.id,
        requestId: 'stable-request-id',
        items: [line],
        paymentMethod: CheckoutPaymentMethod.cash,
        amountPaid: 50000,
      );

      expect(retried.id, first.id);
      expect(store.transactions.length, before + 1);
    },
  );
}
