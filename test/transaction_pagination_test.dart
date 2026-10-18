import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';
import 'package:umkm_manager/features/transactions/data/transaction_repository.dart';
import 'package:umkm_manager/features/transactions/domain/sales_transaction.dart';
import 'package:umkm_manager/features/transactions/presentation/views/transactions_page.dart';

void main() {
  testWidgets('transaction history appends a cursor page without duplicates', (
    tester,
  ) async {
    final repository = _TransactionPageFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: TransactionsPage(
            business: Business(
              id: 'business-1',
              name: 'Toko Uji',
              type: BusinessType.retail,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('INV-001'), findsOneWidget);

    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pumpAndSettle();
    expect(repository.cursors.last, isNotNull);
    expect(find.text('INV-001'), findsOneWidget);
    expect(find.text('INV-002'), findsOneWidget);
  });
}

class _TransactionPageFake implements TransactionRepository {
  final cursors = <TransactionCursor?>[];

  @override
  Future<TransactionPage> getTransactions({
    required String businessId,
    TransactionCursor? cursor,
  }) async {
    cursors.add(cursor);
    if (cursor != null) {
      return TransactionPage(items: [_transaction('2', 'INV-002')]);
    }
    return TransactionPage(
      items: [_transaction('1', 'INV-001')],
      nextCursor: TransactionCursor(
        id: '1',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
  }

  SalesTransaction _transaction(String id, String invoice) => SalesTransaction(
    id: id,
    invoiceNumber: invoice,
    total: 10000,
    paymentMethod: 'CASH',
    createdAt: DateTime.utc(2026, 1, 2),
  );

  @override
  Future<SalesTransaction> checkout({
    required String businessId,
    required String requestId,
    required List<CheckoutLine> items,
    required CheckoutPaymentMethod paymentMethod,
    required int amountPaid,
    String? customerId,
    int discountAmount = 0,
  }) => throw UnimplementedError();

  @override
  Future<SalesTransaction> getTransactionDetail({
    required String businessId,
    required String transactionId,
  }) => throw UnimplementedError();
}
