import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../ai_business_builder/domain/ai_business_builder_exception.dart';
import '../../businesses/domain/business.dart';
import '../domain/feature_prompt_recommendation.dart';

abstract interface class FeaturePromptRepository {
  Future<FeaturePromptRecommendation> recommend({
    required Business business,
    required String prompt,
  });
}

final featurePromptRepositoryProvider = Provider<FeaturePromptRepository>((
  ref,
) {
  if (ref.watch(appConfigProvider).isDevelopmentPreview) {
    return const MockFeaturePromptRepository();
  }
  return SupabaseFeaturePromptRepository(ref.watch(supabaseClientProvider));
});

class SupabaseFeaturePromptRepository implements FeaturePromptRepository {
  const SupabaseFeaturePromptRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<FeaturePromptRecommendation> recommend({
    required Business business,
    required String prompt,
  }) async {
    try {
      final requestId = const Uuid().v4();
      final payload = {
        'businessName': business.name,
        'businessType': business.type.databaseValue,
        'description':
            'Usaha ${business.name} membutuhkan pengelolaan operasional.',
        'featurePrompt': prompt.trim(),
      };
      final response = await _client.functions
          .invoke(
            'recommend-business-config',
            body: {
              'action': 'feature_request',
              'request_id': requestId,
              'payload': payload,
            },
          )
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      if (data is! Map) {
        throw AiBusinessBuilderException.fromCode('AI_INVALID_RESPONSE');
      }
      final json = Map<String, dynamic>.from(data);
      if (json['success'] == false) {
        throw AiBusinessBuilderException.fromCode(json['code'] as String?);
      }
      final key = json['key'];
      final name = json['name'];
      final reason = json['reason'];
      if (key is! String || name is! String || reason is! String) {
        throw AiBusinessBuilderException.fromCode('AI_INVALID_RESPONSE');
      }
      return FeaturePromptRecommendation(key: key, name: name, reason: reason);
    } on TimeoutException {
      throw AiBusinessBuilderException.fromCode('AI_TIMEOUT');
    } on FunctionsFetchException {
      throw AiBusinessBuilderException.fromCode('NETWORK_ERROR');
    } on FunctionsRelayException {
      throw AiBusinessBuilderException.fromCode('AI_PROVIDER_ERROR');
    } on FunctionsHttpException catch (error) {
      final details = error.details;
      if (details is Map && details['code'] is String) {
        throw AiBusinessBuilderException.fromCode(details['code'] as String);
      }
      throw AiBusinessBuilderException.fromStatus(error.status);
    }
  }
}

class MockFeaturePromptRepository implements FeaturePromptRepository {
  const MockFeaturePromptRepository();

  @override
  Future<FeaturePromptRecommendation> recommend({
    required Business business,
    required String prompt,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final input = prompt.toLowerCase();
    if (RegExp(r'\b(stok|persediaan|bahan|habis|menipis)\b').hasMatch(input)) {
      return const FeaturePromptRecommendation(
        key: 'products',
        name: 'Produk',
        reason: 'Mengatur produk beserta persediaan yang dijual.',
      );
    }
    if (RegExp(r'\b(pelanggan|member|langganan|crm)\b').hasMatch(input)) {
      return const FeaturePromptRecommendation(
        key: 'customers',
        name: 'Pelanggan',
        reason: 'Menyimpan dan mencari data pelanggan.',
      );
    }
    if (RegExp(r'\b(menu|produk|katalog|barang)\b').hasMatch(input)) {
      return const FeaturePromptRecommendation(
        key: 'products',
        name: 'Produk',
        reason: 'Mencatat katalog produk atau menu yang dijual.',
      );
    }
    if (RegExp(
      r'\b(kasir|checkout|pesanan|bayar|pembayaran)\b',
    ).hasMatch(input)) {
      return const FeaturePromptRecommendation(
        key: 'cashier',
        name: 'Kasir',
        reason: 'Mencatat pesanan dan pembayaran pelanggan.',
      );
    }
    if (RegExp(r'\b(laporan|riwayat|penjualan|transaksi)\b').hasMatch(input)) {
      return const FeaturePromptRecommendation(
        key: 'transactions',
        name: 'Transaksi',
        reason: 'Melihat riwayat transaksi penjualan usaha.',
      );
    }
    return const FeaturePromptRecommendation(
      key: 'custom_records',
      name: 'Catatan usaha',
      reason: 'Mencatat kebutuhan usaha sesuai permintaan Anda.',
    );
  }
}
