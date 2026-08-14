import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/core/utils/navigation_label_formatter.dart';
import 'package:umkm_manager/features/ai_business_builder/data/mock_ai_business_builder_repository.dart';
import 'package:umkm_manager/features/ai_business_builder/data/business_onboarding_repository.dart';
import 'package:umkm_manager/features/ai_business_builder/domain/ai_business_builder_exception.dart';
import 'package:umkm_manager/features/ai_business_builder/domain/business_recommendation_request.dart';
import 'package:umkm_manager/features/business_configuration/domain/business_configuration.dart';
import 'package:umkm_manager/features/business_configuration/domain/business_capability_registry.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';
import 'package:umkm_manager/features/development_preview/data/development_preview_store.dart';

void main() {
  const repository = MockAiBusinessBuilderRepository();

  test(
    'fixture preview fotografi hanya memberi capability yang sudah usable',
    () async {
      final config = await repository.recommend(
        const BusinessRecommendationRequest(
          businessName: 'Cahaya Studio',
          businessType: 'Fotografi',
          description:
              'Wedding dan wisuda, menerima booking serta DP dengan beberapa fotografer.',
        ),
      );
      expect(
        config.features.where((item) => item.enabled).map((item) => item.key),
        everyElement(
          predicate<String>(
            (key) =>
                BusinessCapabilityRegistry.byKey(key)!.template.isImplemented,
          ),
        ),
      );
      expect(config.features.map((item) => item.key), contains('customers'));
      expect(config.paymentRule.suggestedDownPaymentPercent, 30);
    },
  );

  test(
    'fixture preview laundry dan retail memberi capability sesuai alur',
    () async {
      final laundry = await repository.recommend(
        const BusinessRecommendationRequest(
          businessName: 'Bersih',
          businessType: 'Laundry',
          description:
              'Laundry kiloan dengan antar jemput dan order pelanggan.',
        ),
      );
      final retail = await repository.recommend(
        const BusinessRecommendationRequest(
          businessName: 'Sembako',
          businessType: 'Toko',
          description:
              'Toko sembako dengan stok, kasir, transaksi dan pelanggan.',
        ),
      );
      expect(laundry.features.map((item) => item.key), contains('customers'));
      expect(
        retail.features.map((item) => item.key),
        containsAll(['products', 'cashier', 'transactions', 'customers']),
      );
    },
  );

  test('parser menolak capability di luar registry', () {
    expect(
      () => BusinessConfiguration.fromJson({
        'businessCategory': 'test',
        'summary': 'Ringkasan',
        'recommendedFeatures': [
          {
            'key': 'gps_tracking',
            'name': 'GPS',
            'enabled': true,
            'reason': 'Tidak aman',
          },
        ],
        'customFields': [],
        'workflow': [],
        'paymentRules': {'supportsDownPayment': false},
        'dashboardWidgets': [],
        'unsupportedRequirements': [],
      }),
      throwsFormatException,
    );
  });

  test('parser menolak action yang tidak didukung capability', () {
    expect(
      () => BusinessConfiguration.fromJson({
        'businessCategory': 'test',
        'summary': 'Ringkasan',
        'recommendedFeatures': [
          {
            'key': 'customers',
            'name': 'Pelanggan',
            'enabled': true,
            'reason': 'Dibutuhkan',
            'actions': ['list', 'print_label'],
          },
        ],
        'customFields': [],
        'workflow': [],
        'paymentRules': {'supportsDownPayment': false},
        'dashboardWidgets': [],
        'unsupportedRequirements': [],
      }),
      throwsFormatException,
    );
  });

  test('error Gemini dipetakan ke pesan aman berbahasa Indonesia', () {
    final error = AiBusinessBuilderException.fromCode('GEMINI_MODEL_NOT_FOUND');
    expect(error.code, 'GEMINI_MODEL_NOT_FOUND');
    expect(error.message, contains('Model AI belum tersedia'));
    expect(
      AiBusinessBuilderException.fromStatus(429).code,
      'GEMINI_RATE_LIMIT',
    );
  });

  test('onboarding preview membuat usaha dan konfigurasi bersama', () async {
    final store = DevelopmentPreviewStore();
    final config = await repository.recommend(
      const BusinessRecommendationRequest(
        businessName: 'Alat Berat',
        businessType: 'Penjualan sparepart alat berat',
        description:
            'Menjual baut dan sparepart, mencatat stok, pemasukan, dan pengeluaran.',
      ),
    );
    final onboarding = MockBusinessOnboardingRepository(store);

    await onboarding.createBusinessWithConfiguration(
      name: 'Alat Berat',
      type: BusinessType.other,
      configuration: config,
    );

    expect(store.business.name, 'Alat Berat');
    expect(store.configurations[store.business.id], same(config));
  });

  test('label navigasi panjang memakai nama capability yang ringkas', () {
    expect(
      NavigationLabelFormatter.compact(
        configuredName: 'Riwayat Transaksi dan Invoice Penjualan',
        capabilityName: 'Transaksi',
      ),
      'Transaksi',
    );
    expect(
      NavigationLabelFormatter.compact(
        configuredName: 'Kasir',
        capabilityName: 'Kasir',
      ),
      'Kasir',
    );
  });
}
