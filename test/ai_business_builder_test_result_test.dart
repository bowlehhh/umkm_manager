import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/ai_business_builder/domain/ai_business_builder_test_result.dart';

void main() {
  test('log diagnostik AI hanya memuat data aman yang diizinkan', () {
    const result = AiBusinessBuilderTestResult(
      isLoggedIn: true,
      userId: 'user-123',
      httpStatus: 200,
      success: true,
      provider: 'openai',
      model: 'gpt-5-mini',
      responseSource: 'model',
      features: ['products', 'stock', 'cashier'],
    );

    expect(result.safeLog, contains('AI TEST SUCCESS'));
    expect(result.safeLog, contains('User ID: user-123'));
    expect(result.safeLog, contains('HTTP status: 200'));
    expect(result.safeLog, contains('Provider: openai'));
    expect(result.safeLog, contains('Model: gpt-5-mini'));
    expect(result.safeLog, contains('AI response source: model'));
    expect(result.safeLog, contains('Features: [products, stock, cashier]'));
    expect(result.safeLog, isNot(contains('Bearer ')));
    expect(result.safeLog, isNot(contains('refresh_token')));
  });
}
