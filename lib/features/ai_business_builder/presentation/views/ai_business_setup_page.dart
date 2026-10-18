import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../business_configuration/domain/business_capability_registry.dart';
import '../../../business_configuration/domain/business_configuration.dart';
import '../../domain/business_recommendation_request.dart';
import '../controllers/ai_business_setup_controller.dart';

class AiBusinessSetupPage extends ConsumerStatefulWidget {
  const AiBusinessSetupPage({super.key});
  @override
  ConsumerState<AiBusinessSetupPage> createState() =>
      _AiBusinessSetupPageState();
}

class _AiBusinessSetupPageState extends ConsumerState<AiBusinessSetupPage> {
  static const _types = [
    'Kuliner',
    'Retail / Toko',
    'Fotografi',
    'Salon / Barbershop',
    'Laundry',
    'Bengkel',
    'Jasa Profesional',
    'Rental',
    'Lainnya',
  ];
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _customType = TextEditingController();
  BusinessConfiguration? _recommendation;
  String? _submittedName;
  String? _submittedType;
  String? _submittedDescription;
  String _type = _types.first;
  @override
  void dispose() {
    _name.dispose();
    _customType.dispose();
    super.dispose();
  }

  Future<void> _recommend() async {
    if (!_formKey.currentState!.validate()) return;
    final actualType = _type == 'Lainnya' ? _customType.text.trim() : _type;
    final request = BusinessRecommendationRequest(
      businessName: _name.text.trim(),
      businessType: actualType,
      // Pengguna belum perlu menulis prompt. Konteks ringkas ini cukup untuk
      // saran awal dan menjaga token AI tetap kecil.
      description: 'Usaha $actualType bernama ${_name.text.trim()}.',
      initialSetup: true,
    );
    setState(() {
      // Simpan data usaha saat pengguna mengirim formulir. Halaman saran dapat
      // dibangun ulang ketika provider AI berubah, sehingga jangan bergantung
      // lagi pada TextEditingController untuk proses penerapan berikutnya.
      _submittedName = request.businessName;
      _submittedType = request.businessType;
      _submittedDescription = request.description;
    });
    final error = await ref
        .read(aiBusinessSetupControllerProvider.notifier)
        .recommend(request);
    if (mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiBusinessSetupControllerProvider);
    final recommendation = state.asData?.value;
    if (recommendation != null) {
      _recommendation =
          BusinessCapabilityRegistry.withSelectableImplementedFeatures(
            recommendation,
          );
    }
    final displayedRecommendation = _recommendation;
    final submittedName = _submittedName;
    final submittedType = _submittedType;
    final submittedDescription = _submittedDescription;
    if (displayedRecommendation != null &&
        submittedName != null &&
        submittedType != null &&
        submittedDescription != null) {
      return AiRecommendationReviewPage(
        name: submittedName,
        type: submittedType,
        description: submittedDescription,
        initial: displayedRecommendation,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Buat usaha Anda')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buat usaha Anda',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pilih jenis dan nama usaha. AI akan menyiapkan saran fitur yang tersedia untuk Anda pilih.',
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '1. Pilih jenis usaha',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _types
                          .map(
                            (type) => ChoiceChip(
                              label: Text(type),
                              selected: _type == type,
                              onSelected: state.isLoading
                                  ? null
                                  : (_) => setState(() => _type = type),
                            ),
                          )
                          .toList(),
                    ),
                    if (_type == 'Lainnya') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customType,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: 'Tulis jenis usaha',
                        ),
                        validator: (v) =>
                            _type == 'Lainnya' && (v?.trim().isEmpty ?? true)
                            ? 'Jenis usaha wajib diisi.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: '2. Nama usaha',
                        hintText: 'Contoh: Warung Winky',
                        helperText: 'AI akan memberi saran fitur setelah ini.',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 2
                          ? 'Nama usaha minimal 2 karakter.'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: state.isLoading ? null : _recommend,
                      icon: state.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        state.isLoading
                            ? 'Menyusun rekomendasi…'
                            : 'Lihat saran fitur',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hanya fitur yang sudah tersedia di aplikasi yang akan ditampilkan. Fitur yang belum relevan dibiarkan tidak dicentang.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AiRecommendationReviewPage extends ConsumerStatefulWidget {
  const AiRecommendationReviewPage({
    super.key,
    required this.name,
    required this.type,
    required this.description,
    required this.initial,
  });
  final String name;
  final String type;
  final String description;
  final BusinessConfiguration initial;
  @override
  ConsumerState<AiRecommendationReviewPage> createState() =>
      _AiRecommendationReviewPageState();
}

class _AiRecommendationReviewPageState
    extends ConsumerState<AiRecommendationReviewPage> {
  late BusinessConfiguration _config = widget.initial;
  final _additionalNeeds = TextEditingController();
  String? _applyError;
  @override
  void dispose() {
    _additionalNeeds.dispose();
    super.dispose();
  }

  void _changeConfiguration(BusinessConfiguration next) {
    if (next.toJson().toString() == _config.toJson().toString()) return;
    setState(() => _config = next);
  }

  void _updateFeature(BusinessFeatureConfig feature, {bool? enabled}) =>
      _changeConfiguration(
        _config.copyWith(
          features: _config.features
              .map(
                (item) => item.key == feature.key
                    ? item.copyWith(enabled: enabled)
                    : item,
              )
              .toList(),
        ),
      );

  Future<void> _requestAdditionalSuggestion() async {
    final needs = _additionalNeeds.text.trim();
    if (needs.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tulis kebutuhan tambahan Anda terlebih dahulu.'),
        ),
      );
      return;
    }

    final error = await ref
        .read(aiBusinessSetupControllerProvider.notifier)
        .recommend(
          BusinessRecommendationRequest(
            businessName: widget.name,
            businessType: widget.type,
            description: widget.description,
            additionalNeeds: needs,
          ),
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final recommendation = ref.read(aiBusinessSetupControllerProvider).value;
    if (recommendation != null) {
      setState(
        () => _config =
            BusinessCapabilityRegistry.withSelectableImplementedFeatures(
              recommendation,
            ),
      );
      _additionalNeeds.clear();
    }
  }

  Future<void> _apply() async {
    setState(() => _applyError = null);
    final config = _config.copyWith(
      customFields: const [],
      workflow: const [],
      paymentRule: const PaymentRule(supportsDownPayment: false),
    );
    final error = await ref
        .read(aiBusinessSetupControllerProvider.notifier)
        .apply(
          name: widget.name,
          typeLabel: widget.type,
          configuration: config,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _applyError = error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(aiBusinessSetupControllerProvider).isLoading;
    final hasOperationalFeature = _config.features.any(
      (item) => item.enabled && item.key != 'dashboard',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Saran untuk Usaha Anda')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final padding = viewport.maxWidth >= 640 ? 24.0 : 16.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  padding: EdgeInsets.all(padding),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text('Jenis usaha: ${widget.type}'),
                            const SizedBox(height: 12),
                            Text(_config.summary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Pilih fitur untuk usaha Anda',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AI menandai fitur yang cocok. Fitur yang belum dibutuhkan tetap tidak dicentang dan bisa Anda nyalakan sendiri.',
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 780
                            ? 3
                            : constraints.maxWidth >= 500
                            ? 2
                            : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _config.features.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: columns == 1 ? 124 : 140,
                              ),
                          itemBuilder: (context, index) {
                            final feature = _config.features[index];
                            final capability = BusinessCapabilityRegistry.byKey(
                              feature.key,
                            );
                            return _FeatureChoiceCard(
                              feature: feature,
                              icon:
                                  capability?.icon ?? Icons.extension_outlined,
                              required: feature.key == 'dashboard',
                              onChanged: isLoading || feature.key == 'dashboard'
                                  ? null
                                  : (value) =>
                                        _updateFeature(feature, enabled: value),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Butuh fitur lain?',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tulis kebutuhan Anda. AI akan menyesuaikan saran dengan fitur yang tersedia di aplikasi.',
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _additionalNeeds,
                              maxLength: 500,
                              minLines: 2,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Kebutuhan tambahan',
                                hintText:
                                    'Contoh: Saya ingin mencatat pesanan pelanggan lewat WhatsApp.',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonalIcon(
                                onPressed: isLoading
                                    ? null
                                    : _requestAdditionalSuggestion,
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: const Text('Minta saran AI'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_config.unsupportedRequirements.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Catatan untuk usaha Anda',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ..._config.unsupportedRequirements.map(
                        (item) => ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: Text(item.name),
                          subtitle: Text(item.reason),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: isLoading || !hasOperationalFeature
                          ? null
                          : _apply,
                      icon: isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        isLoading ? 'Menyimpan…' : 'Gunakan saran ini',
                      ),
                    ),
                    if (_applyError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _applyError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (!hasOperationalFeature)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Aktifkan minimal satu fitur selain Beranda untuk menerapkan konfigurasi.',
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureChoiceCard extends StatelessWidget {
  const _FeatureChoiceCard({
    required this.feature,
    required this.icon,
    required this.required,
    required this.onChanged,
  });

  final BusinessFeatureConfig feature;
  final IconData icon;
  final bool required;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(icon, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  feature.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (required)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Chip(label: Text('Utama')),
            )
          else
            Switch(value: feature.enabled, onChanged: onChanged),
        ],
      ),
    ),
  );
}
