import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';
import '../../../../shared/widgets/main_navigation_scaffold.dart';
import '../../../development_preview/presentation/views/preview_feature_page.dart';
import '../../../business_configuration/data/business_configuration_repository.dart';
import '../../../business_configuration/domain/business_capability_registry.dart';
import '../../../business_configuration/domain/business_configuration.dart';
import '../../data/business_repository.dart';
import '../../domain/business.dart';
import 'business_selector_page.dart';

class BusinessGate extends ConsumerWidget {
  const BusinessGate({
    super.key,
    required this.currentRoute,
    this.previewFeature,
    this.featureKey,
    this.childBuilder,
  });

  final String currentRoute;
  final PreviewFeature? previewFeature;
  final String? featureKey;
  final Widget Function(Business business, BusinessConfiguration configuration)?
  childBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeBusinessProvider);
    return business.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Data bisnis belum dapat dimuat. Periksa koneksi lalu coba lagi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(businessSessionProvider.notifier).refresh(),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (value) {
        if (value == null) return const BusinessFlowPage();
        final config = ref.watch(businessConfigurationProvider(value.id));
        return config.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => MainNavigationScaffold(
            business: value,
            configuration: BusinessCapabilityRegistry.legacyConfiguration(
              value,
            ),
            currentRoute: currentRoute,
          ),
          data: (saved) {
            final configuration =
                BusinessCapabilityRegistry.usableConfiguration(value, saved);
            final isEnabled =
                featureKey == null ||
                configuration.features.any(
                  (item) => item.key == featureKey && item.enabled,
                );
            if (!isEnabled) {
              final capability = BusinessCapabilityRegistry.byKey(featureKey!);
              return FeaturePlaceholderPage(
                title: capability?.name ?? 'Fitur',
                icon: capability?.icon ?? Icons.lock_outline,
                description:
                    'Fitur ini tidak aktif pada konfigurasi usaha Anda.',
              );
            }
            if (previewFeature != null) {
              if (ref.watch(appConfigProvider).isDevelopmentPreview) {
                return PreviewFeaturePage(feature: previewFeature!);
              }
              return FeaturePlaceholderPage(
                title: previewFeature!.title,
                icon: previewFeature!.icon,
                description: 'Fitur ini sedang disiapkan.',
              );
            }
            if (childBuilder != null) {
              return childBuilder!(value, configuration);
            }
            return MainNavigationScaffold(
              business: value,
              configuration: configuration,
              currentRoute: currentRoute,
            );
          },
        );
      },
    );
  }
}
