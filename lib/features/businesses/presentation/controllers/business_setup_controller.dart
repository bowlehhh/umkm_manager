import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_mapper.dart';
import '../../../business_configuration/data/business_configuration_repository.dart';
import '../../../categories/data/category_repository.dart';
import '../../../products/data/product_repository.dart';
import '../../../transactions/data/transaction_repository.dart';
import '../../../transactions/presentation/controllers/checkout_controller.dart';
import '../../data/business_repository.dart';
import '../../domain/business.dart';

final businessSetupControllerProvider =
    NotifierProvider<BusinessSetupController, AsyncValue<void>>(
      BusinessSetupController.new,
    );

class BusinessSetupController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> createBusiness({
    required String name,
    required BusinessType type,
    String? address,
    String? phone,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(businessRepositoryProvider)
          .createBusiness(
            name: name,
            type: type,
            address: address,
            phone: phone,
          );
      await ref.read(businessSessionProvider.notifier).refresh();
      state = const AsyncData(null);
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AppErrorMapper.message(error);
    }
  }

  Future<String?> selectBusiness(String businessId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(businessSessionProvider.notifier)
          .selectBusiness(businessId);
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(transactionDetailProvider);
      ref.invalidate(businessConfigurationProvider);
      ref.invalidate(checkoutControllerProvider);
      state = const AsyncData(null);
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AppErrorMapper.message(error);
    }
  }
}
