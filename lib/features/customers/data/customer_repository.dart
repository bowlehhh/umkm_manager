import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/customer.dart';
import 'mock_customer_repository.dart';
import 'supabase_customer_repository.dart';

abstract interface class CustomerRepository {
  Future<CustomerPage> getCustomers({
    required String businessId,
    String search,
    CustomerCursor? cursor,
  });
  Future<Customer> getCustomer({
    required String businessId,
    required String customerId,
  });
  Future<void> saveCustomer({
    required String businessId,
    Customer? existing,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  });
  Future<void> archiveCustomer({
    required String businessId,
    required String customerId,
  });
  Future<List<CustomerTransactionSummary>> getTransactions({
    required String businessId,
    required String customerId,
  });
  Future<CustomerDebtSummary> getDebtSummary({
    required String businessId,
    required String customerId,
  });
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  if (ref.watch(appConfigProvider).isDevelopmentPreview) {
    return MockCustomerRepository();
  }
  return SupabaseCustomerRepository(ref.watch(supabaseClientProvider));
});

typedef CustomerKey = ({String businessId, String customerId});

final customerProvider = FutureProvider.family<Customer, CustomerKey>(
  (ref, key) => ref
      .watch(customerRepositoryProvider)
      .getCustomer(businessId: key.businessId, customerId: key.customerId),
);

final customerTransactionsProvider =
    FutureProvider.family<List<CustomerTransactionSummary>, CustomerKey>(
      (ref, key) => ref
          .watch(customerRepositoryProvider)
          .getTransactions(
            businessId: key.businessId,
            customerId: key.customerId,
          ),
    );

final customerDebtSummaryProvider =
    FutureProvider.family<CustomerDebtSummary, CustomerKey>(
      (ref, key) => ref
          .watch(customerRepositoryProvider)
          .getDebtSummary(
            businessId: key.businessId,
            customerId: key.customerId,
          ),
    );
