import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../development_preview/data/development_preview_store.dart';
import '../domain/business_configuration.dart';
import 'mock_business_configuration_repository.dart';
import 'supabase_business_configuration_repository.dart';

abstract interface class BusinessConfigurationRepository {
  Future<BusinessConfiguration?> getConfiguration(String businessId);
  Future<void> saveConfiguration(
    String businessId,
    BusinessConfiguration configuration,
  );
}

final businessConfigurationRepositoryProvider =
    Provider<BusinessConfigurationRepository>((ref) {
      if (ref.watch(appConfigProvider).isDevelopmentPreview) {
        return MockBusinessConfigurationRepository(
          ref.watch(developmentPreviewStoreProvider),
        );
      }
      return SupabaseBusinessConfigurationRepository(
        ref.watch(supabaseClientProvider),
      );
    });

final businessConfigurationProvider =
    FutureProvider.family<BusinessConfiguration?, String>(
      (ref, businessId) => ref
          .watch(businessConfigurationRepositoryProvider)
          .getConfiguration(businessId),
    );
