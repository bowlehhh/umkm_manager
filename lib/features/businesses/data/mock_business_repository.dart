import '../../development_preview/data/development_preview_store.dart';
import '../domain/business.dart';
import 'business_repository.dart';

class MockBusinessRepository implements BusinessRepository {
  MockBusinessRepository(this._store);

  final DevelopmentPreviewStore _store;

  @override
  Future<List<Business>> getBusinesses() async =>
      List.unmodifiable(_store.businesses);

  @override
  Future<Business?> getActiveBusiness() async => _store.business;

  @override
  Future<void> setActiveBusiness(String businessId) async {
    _store.activateBusiness(businessId);
  }

  @override
  Future<Business> createBusiness({
    required String name,
    required BusinessType type,
    String? address,
    String? phone,
  }) async {
    final business = Business(
      id: 'preview-business-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      type: type,
      address: address?.trim(),
      phone: phone?.trim(),
      isActive: true,
    );
    _store.businesses.add(business);
    _store.activateBusiness(business.id);
    return business;
  }
}
