import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../business_configuration/domain/business_configuration.dart';
import '../domain/ai_business_builder_exception.dart';
import '../domain/business_recommendation_request.dart';
import 'ai_business_builder_repository.dart';

class SupabaseAiBusinessBuilderRepository
    implements AiBusinessBuilderRepository {
  const SupabaseAiBusinessBuilderRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<BusinessConfiguration> recommend(
    BusinessRecommendationRequest request,
  ) async {
    try {
      final response = await _client.functions
          .invoke('recommend-business-config', body: request.toJson())
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      if (data is! Map) {
        throw AiBusinessBuilderException.fromCode('AI_INVALID_RESPONSE');
      }
      final json = Map<String, dynamic>.from(data);
      if (json['success'] == false) {
        final code = json['code'];
        throw AiBusinessBuilderException.fromCode(code is String ? code : null);
      }
      try {
        return BusinessConfiguration.fromJson(json);
      } on FormatException {
        throw AiBusinessBuilderException.fromCode('AI_INVALID_RESPONSE');
      }
    } on TimeoutException {
      throw AiBusinessBuilderException.fromCode('AI_TIMEOUT');
    } on FunctionsFetchException {
      throw AiBusinessBuilderException.fromCode('NETWORK_ERROR');
    } on FunctionsRelayException {
      throw AiBusinessBuilderException.fromCode('AI_PROVIDER_ERROR');
    } on FunctionsHttpException catch (error) {
      final details = error.details;
      if (details is Map) {
        final code = details['code'];
        if (code is String) {
          throw AiBusinessBuilderException.fromCode(code);
        }
      }
      throw AiBusinessBuilderException.fromStatus(error.status);
    }
  }
}
