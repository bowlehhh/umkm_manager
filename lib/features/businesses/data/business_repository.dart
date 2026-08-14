import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../development_preview/data/development_preview_store.dart';
import '../domain/business.dart';
import 'mock_business_repository.dart';
import 'supabase_business_repository.dart';

abstract interface class BusinessRepository {
  Future<List<Business>> getBusinesses();

  Future<Business?> getActiveBusiness();

  Future<void> setActiveBusiness(String businessId);

  Future<Business> createBusiness({
    required String name,
    required BusinessType type,
    String? address,
    String? phone,
  });
}

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  if (ref.watch(appConfigProvider).isDevelopmentPreview) {
    return MockBusinessRepository(ref.watch(developmentPreviewStoreProvider));
  }
  return SupabaseBusinessRepository(ref.watch(supabaseClientProvider));
});

class BusinessSession {
  const BusinessSession(this.businesses);

  final List<Business> businesses;

  Business? get activeBusiness {
    for (final business in businesses) {
      if (business.isActive) return business;
    }
    return null;
  }

  bool get hasBusinesses => businesses.isNotEmpty;
}

class BusinessSessionNotifier extends AsyncNotifier<BusinessSession> {
  @override
  Future<BusinessSession> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> selectBusiness(String businessId) async {
    await ref.read(businessRepositoryProvider).setActiveBusiness(businessId);
    await refresh();
  }

  Future<BusinessSession> _load() async => BusinessSession(
    await ref.read(businessRepositoryProvider).getBusinesses(),
  );
}

final businessSessionProvider =
    AsyncNotifierProvider<BusinessSessionNotifier, BusinessSession>(
      BusinessSessionNotifier.new,
    );

final activeBusinessProvider = Provider<AsyncValue<Business?>>(
  (ref) => ref
      .watch(businessSessionProvider)
      .whenData((session) => session.activeBusiness),
);

final businessesProvider = Provider<AsyncValue<List<Business>>>(
  (ref) => ref
      .watch(businessSessionProvider)
      .whenData((session) => session.businesses),
);
