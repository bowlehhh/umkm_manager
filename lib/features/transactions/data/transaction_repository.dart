import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../development_preview/data/development_preview_store.dart';
import '../domain/sales_transaction.dart';
import 'mock_transaction_repository.dart';
import 'supabase_transaction_repository.dart';

abstract interface class TransactionRepository {
  Future<List<SalesTransaction>> getTransactions(String businessId);

  Future<SalesTransaction> getTransactionDetail({
    required String businessId,
    required String transactionId,
  });

  Future<SalesTransaction> checkout({
    required String businessId,
    required List<CheckoutLine> items,
    required CheckoutPaymentMethod paymentMethod,
    required int amountPaid,
    int discountAmount,
  });
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  if (ref.watch(appConfigProvider).isDevelopmentPreview) {
    return MockTransactionRepository(
      ref.watch(developmentPreviewStoreProvider),
    );
  }
  return SupabaseTransactionRepository(ref.watch(supabaseClientProvider));
});

final transactionsProvider =
    FutureProvider.family<List<SalesTransaction>, String>(
      (ref, businessId) =>
          ref.watch(transactionRepositoryProvider).getTransactions(businessId),
    );

typedef TransactionDetailKey = ({String businessId, String transactionId});

final transactionDetailProvider =
    FutureProvider.family<SalesTransaction, TransactionDetailKey>(
      (ref, key) => ref
          .watch(transactionRepositoryProvider)
          .getTransactionDetail(
            businessId: key.businessId,
            transactionId: key.transactionId,
          ),
    );
