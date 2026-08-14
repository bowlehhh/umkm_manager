class BusinessRecommendationRequest {
  const BusinessRecommendationRequest({
    required this.businessName,
    required this.businessType,
    required this.description,
  });
  final String businessName;
  final String businessType;
  final String description;
  Map<String, String> toJson() => {
    'businessName': businessName.trim(),
    'businessType': businessType.trim(),
    'description': description.trim(),
  };
}
