import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../business_configuration/domain/business_configuration.dart';
import '../domain/business_recommendation_request.dart';
import 'mock_ai_business_builder_repository.dart';
import 'supabase_ai_business_builder_repository.dart';

abstract interface class AiBusinessBuilderRepository {
  Future<BusinessConfiguration> recommend(
    BusinessRecommendationRequest request,
  );
}

final aiBusinessBuilderRepositoryProvider =
    Provider<AiBusinessBuilderRepository>((ref) {
      if (ref.watch(appConfigProvider).isDevelopmentPreview) {
        return const MockAiBusinessBuilderRepository();
      }
      return SupabaseAiBusinessBuilderRepository(
        ref.watch(supabaseClientProvider),
      );
    });
