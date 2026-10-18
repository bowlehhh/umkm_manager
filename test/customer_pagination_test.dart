import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';
import 'package:umkm_manager/features/customers/data/customer_repository.dart';
import 'package:umkm_manager/features/customers/domain/customer.dart';
import 'package:umkm_manager/features/customers/presentation/views/customers_page.dart';

void main() {
  testWidgets('customer search is debounced and pagination passes a cursor', (
    tester,
  ) async {
    final repository = _CustomerPageFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [customerRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: CustomersPage(
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
    expect(repository.requests, hasLength(1));
    expect(find.text('Andi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Budi');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.requests, hasLength(1));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(repository.requests.last.search, 'Budi');
    expect(find.widgetWithText(ListTile, 'Budi'), findsOneWidget);

    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pumpAndSettle();
    expect(repository.requests.last.cursor, isNotNull);
    expect(find.text('Citra'), findsOneWidget);
  });
}

class _CustomerPageFake implements CustomerRepository {
  final requests = <({String search, CustomerCursor? cursor})>[];

  @override
  Future<CustomerPage> getCustomers({
    required String businessId,
    String search = '',
    CustomerCursor? cursor,
  }) async {
    requests.add((search: search, cursor: cursor));
    if (cursor != null) {
      return CustomerPage(items: [_customer('3', 'Citra')]);
    }
    if (search == 'Budi') {
      return CustomerPage(
        items: [_customer('2', 'Budi')],
        nextCursor: CustomerCursor(
          id: '2',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      );
    }
    return CustomerPage(
      items: [_customer('1', 'Andi')],
      nextCursor: CustomerCursor(id: '1', createdAt: DateTime.utc(2026, 1, 1)),
    );
  }

  Customer _customer(String id, String name) =>
      Customer(id: id, businessId: 'business-1', name: name, isActive: true);

  @override
  Future<void> archiveCustomer({
    required String businessId,
    required String customerId,
  }) async {}

  @override
  Future<Customer> getCustomer({
    required String businessId,
    required String customerId,
  }) => throw UnimplementedError();

  @override
  Future<CustomerDebtSummary> getDebtSummary({
    required String businessId,
    required String customerId,
  }) => throw UnimplementedError();

  @override
  Future<List<CustomerTransactionSummary>> getTransactions({
    required String businessId,
    required String customerId,
  }) => throw UnimplementedError();

  @override
  Future<void> saveCustomer({
    required String businessId,
    Customer? existing,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {}
}
