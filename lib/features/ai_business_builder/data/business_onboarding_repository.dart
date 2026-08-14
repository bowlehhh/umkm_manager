import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../business_configuration/domain/business_configuration.dart';
import '../../businesses/domain/business.dart';
import '../../development_preview/data/development_preview_store.dart';

abstract interface class BusinessOnboardingRepository {
  Future<void> createBusinessWithConfiguration({
    required String name,
    required BusinessType type,
    required BusinessConfiguration configuration,
    String? address,
    String? phone,
  });
}

final businessOnboardingRepositoryProvider =
    Provider<BusinessOnboardingRepository>((ref) {
      if (ref.watch(appConfigProvider).isDevelopmentPreview) {
        return MockBusinessOnboardingRepository(
          ref.watch(developmentPreviewStoreProvider),
        );
      }
      return SupabaseBusinessOnboardingRepository(
        ref.watch(supabaseClientProvider),
      );
    });

class SupabaseBusinessOnboardingRepository
    implements BusinessOnboardingRepository {
  const SupabaseBusinessOnboardingRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> createBusinessWithConfiguration({
    required String name,
    required BusinessType type,
    required BusinessConfiguration configuration,
    String? address,
    String? phone,
  }) async {
    await _client
        .rpc(
          'create_business_with_owner_and_configuration',
          params: {
            'business_name': name.trim(),
            'business_configuration': configuration.toJson(),
            'business_address': address?.trim(),
            'business_phone': phone?.trim(),
            'business_type': type.databaseValue,
          },
        )
        .timeout(const Duration(seconds: 25));
  }
}

class MockBusinessOnboardingRepository implements BusinessOnboardingRepository {
  const MockBusinessOnboardingRepository(this._store);
  final DevelopmentPreviewStore _store;

  @override
  Future<void> createBusinessWithConfiguration({
    required String name,
    required BusinessType type,
    required BusinessConfiguration configuration,
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
    _store.configurations[business.id] = configuration;
    _store.activateBusiness(business.id);
  }
}
