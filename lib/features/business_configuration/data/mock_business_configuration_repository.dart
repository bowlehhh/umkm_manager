import '../../development_preview/data/development_preview_store.dart';
import '../domain/business_configuration.dart';
import 'business_configuration_repository.dart';

class MockBusinessConfigurationRepository
    implements BusinessConfigurationRepository {
  const MockBusinessConfigurationRepository(this._store);
  final DevelopmentPreviewStore _store;
  @override
  Future<BusinessConfiguration?> getConfiguration(String businessId) async =>
      _store.configurations[businessId];
  @override
  Future<void> saveConfiguration(
    String businessId,
    BusinessConfiguration configuration,
  ) async => _store.configurations[businessId] = configuration;
}
