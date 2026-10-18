import 'package:uuid/uuid.dart';

class BusinessRecommendationRequest {
  const BusinessRecommendationRequest({
    required this.businessName,
    required this.businessType,
    required this.description,
    this.additionalNeeds = '',
    this.initialSetup = false,
  });
  final String businessName;
  final String businessType;
  final String description;
  final String additionalNeeds;

  /// Rekomendasi awal hanya memakai nama dan jenis usaha. Server memakai
  /// batas output yang lebih kecil agar pembukaan usaha tidak boros kredit AI.
  final bool initialSetup;
  Map<String, dynamic> toJson() {
    final requestId = const Uuid().v4();
    final payload = {
      'businessName': businessName.trim(),
      'businessType': businessType.trim(),
      'description': description.trim(),
      'additionalNeeds': additionalNeeds.trim(),
      'initialSetup': initialSetup,
    };
    return {
      // New Edge Functions use this provider-independent envelope.
      'action': 'business_builder',
      'request_id': requestId,
      'payload': payload,
      // Keep deployed pre-envelope functions working until their next deploy.
      ...payload,
    };
  }
}
