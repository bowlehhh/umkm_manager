import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_error_mapper.dart';
import '../../../products/data/product_repository.dart';
import '../../data/transaction_repository.dart';
import '../../domain/sales_transaction.dart';

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, AsyncValue<SalesTransaction?>>(
      CheckoutController.new,
    );

class CheckoutController extends Notifier<AsyncValue<SalesTransaction?>> {
  String? _pendingRequestId;

  @override
  AsyncValue<SalesTransaction?> build() => const AsyncData(null);

  Future<String?> checkout({
    required String businessId,
    required List<CheckoutLine> items,
    required CheckoutPaymentMethod paymentMethod,
    required int amountPaid,
  }) async {
    state = const AsyncLoading();
    final requestId = _pendingRequestId ??= const Uuid().v4();
    try {
      final transaction = await ref
          .read(transactionRepositoryProvider)
          .checkout(
            businessId: businessId,
            requestId: requestId,
            items: items,
            paymentMethod: paymentMethod,
            amountPaid: amountPaid,
          );
      ref.invalidate(productsProvider(businessId));
      ref.invalidate(transactionsProvider(businessId));
      state = AsyncData(transaction);
      _pendingRequestId = null;
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AppErrorMapper.message(error);
    }
  }
}
