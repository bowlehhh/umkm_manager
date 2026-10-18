import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_mapper.dart';
import '../../data/business_configuration_repository.dart';
import '../../domain/business_configuration.dart';

final businessConfigurationControllerProvider =
    NotifierProvider<BusinessConfigurationController, AsyncValue<void>>(
      BusinessConfigurationController.new,
    );

class BusinessConfigurationController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> save({
    required String businessId,
    required BusinessConfiguration configuration,
  }) async {
    state = const AsyncLoading();
    try {
      configuration.validated();
      await ref
          .read(businessConfigurationRepositoryProvider)
          .saveConfiguration(businessId, configuration);
      ref.invalidate(businessConfigurationProvider(businessId));
      state = const AsyncData(null);
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return AppErrorMapper.message(error);
    }
  }
}
