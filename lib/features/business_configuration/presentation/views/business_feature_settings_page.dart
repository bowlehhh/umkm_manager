import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai_business_builder/domain/ai_business_builder_exception.dart';
import '../../../businesses/domain/business.dart';
import '../../data/feature_prompt_repository.dart';
import '../../domain/business_capability_registry.dart';
import '../../domain/business_configuration.dart';
import '../controllers/business_configuration_controller.dart';

/// Pengaturan hasil AI setelah onboarding. Perubahan tetap lokal sampai pengguna
/// menekan Simpan, sehingga Undo tidak pernah mengubah data usaha secara diam-diam.
class BusinessFeatureSettingsPage extends ConsumerStatefulWidget {
  const BusinessFeatureSettingsPage({
    super.key,
    required this.business,
    required this.initialConfiguration,
  });

  final Business business;
  final BusinessConfiguration initialConfiguration;

  @override
  ConsumerState<BusinessFeatureSettingsPage> createState() =>
      _BusinessFeatureSettingsPageState();
}

class _BusinessFeatureSettingsPageState
    extends ConsumerState<BusinessFeatureSettingsPage> {
  late BusinessConfiguration _configuration = widget.initialConfiguration;
  final List<BusinessConfiguration> _history = [];
  var _isRequestingFeature = false;

  bool get _hasChanges => _history.isNotEmpty;

  void _change(BusinessConfiguration next) {
    if (next.toJson().toString() == _configuration.toJson().toString()) return;
    setState(() {
      _history.add(_configuration);
      _configuration = next;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() => _configuration = _history.removeLast());
  }

  void _discard() => setState(() {
    _configuration = widget.initialConfiguration;
    _history.clear();
  });

  void _updateFeature(BusinessFeatureConfig feature, {bool? enabled}) {
    _change(
      _configuration.copyWith(
        features: _configuration.features
            .map(
              (item) => item.key == feature.key
                  ? item.copyWith(enabled: enabled)
                  : item,
            )
            .toList(),
      ),
    );
  }

  Future<void> _renameFeature(BusinessFeatureConfig feature) async {
    final controller = TextEditingController(text: feature.name);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti nama fitur'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama fitur'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    _change(
      _configuration.copyWith(
        features: _configuration.features
            .map(
              (item) =>
                  item.key == feature.key ? item.copyWith(name: value) : item,
            )
            .toList(),
      ),
    );
  }

  Future<void> _addFeature() async {
    final prompt = await _showFeaturePromptSheet();
    if (prompt == null || prompt.isEmpty || !mounted) return;
    setState(() => _isRequestingFeature = true);
    try {
      final recommendation = await ref
          .read(featurePromptRepositoryProvider)
          .recommend(business: widget.business, prompt: prompt);
      if (!mounted) return;
      if (recommendation.key == 'unsupported') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(recommendation.reason)));
        return;
      }
      final capability = BusinessCapabilityRegistry.byKey(recommendation.key);
      final existing = _configuration.features
          .where((item) => item.key == recommendation.key)
          .firstOrNull;
      if (capability == null || !capability.template.isImplemented) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fitur yang diminta belum siap digunakan.')),
        );
        return;
      }
      if (existing?.enabled == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${recommendation.name} sudah aktif.')),
        );
        return;
      }
      final nextFeature = existing == null
          ? BusinessFeatureConfig(
              key: capability.key,
              name: recommendation.name,
              enabled: true,
              reason: recommendation.reason,
              actions: capability.template.actions.toList()..sort(),
            )
          : existing.copyWith(
              name: recommendation.name,
              enabled: true,
              reason: recommendation.reason,
            );
      _change(
        _configuration.copyWith(
          features: [
            ..._configuration.features.where(
              (feature) => feature.key != nextFeature.key,
            ),
            nextFeature,
          ],
        ),
      );
      final error = await ref
          .read(businessConfigurationControllerProvider.notifier)
          .save(businessId: widget.business.id, configuration: _configuration);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      setState(_history.clear);
      context.go('/dashboard');
    } on AiBusinessBuilderException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isRequestingFeature = false);
    }
  }

  Future<String?> _showFeaturePromptSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FeaturePromptSheet(),
    );
  }

  void _removeFeature(BusinessFeatureConfig feature) {
    if (feature.key == 'dashboard') return;
    _change(
      _configuration.copyWith(
        features: _configuration.features
            .where((item) => item.key != feature.key)
            .toList(),
      ),
    );
  }

  Future<void> _save() async {
    final enabled = _configuration.features.where((item) => item.enabled);
    if (enabled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktifkan minimal satu fitur.')),
      );
      return;
    }
    final error = await ref
        .read(businessConfigurationControllerProvider.notifier)
        .save(businessId: widget.business.id, configuration: _configuration);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(_history.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur usaha berhasil disimpan.')),
    );
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final isSaving =
        ref.watch(businessConfigurationControllerProvider).isLoading ||
        _isRequestingFeature;
    final activeCount = _configuration.features
        .where((item) => item.enabled)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur fitur usaha'),
        actions: [
          IconButton(
            tooltip: 'Batalkan perubahan',
            onPressed: isSaving || !_hasChanges ? null : _discard,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            tooltip: 'Undo perubahan terakhir',
            onPressed: isSaving || !_hasChanges ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hasil rekomendasi AI dapat Anda ubah kapan saja.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '$activeCount fitur aktif. Tambahkan kebutuhan Anda lewat prompt AI.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Fitur', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: isSaving ? null : _addFeature,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            ..._configuration.features.map((feature) {
              final capability = BusinessCapabilityRegistry.byKey(feature.key);
              final isDashboard = feature.key == 'dashboard';
              return Card(
                child: SwitchListTile(
                  value: feature.enabled,
                  onChanged: isSaving || isDashboard
                      ? null
                      : (value) => _updateFeature(feature, enabled: value),
                  secondary: Icon(capability?.icon ?? Icons.extension_outlined),
                  title: Row(
                    children: [
                      Expanded(child: Text(feature.name)),
                      IconButton(
                        tooltip: 'Ganti nama',
                        onPressed: isSaving
                            ? null
                            : () => _renameFeature(feature),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                      if (!isDashboard)
                        IconButton(
                          tooltip: 'Hapus fitur',
                          onPressed: isSaving
                              ? null
                              : () => _removeFeature(feature),
                          icon: const Icon(Icons.delete_outline, size: 19),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    isDashboard
                        ? 'Beranda selalu aktif agar aplikasi tetap memiliki halaman awal.'
                        : feature.reason,
                  ),
                  controlAffinity: ListTileControlAffinity.trailing,
                ),
              );
            }),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isSaving || !_hasChanges ? null : _save,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(isSaving ? 'Menyimpan…' : 'Simpan perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePromptSheet extends StatefulWidget {
  const _FeaturePromptSheet();

  @override
  State<_FeaturePromptSheet> createState() => _FeaturePromptSheetState();
}

class _FeaturePromptSheetState extends State<_FeaturePromptSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buat fitur dengan AI',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Ceritakan kebutuhan Anda. AI akan mencocokkan kebutuhan dengan modul yang sudah benar-benar tersedia dan langsung mengaktifkan yang sesuai.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 220,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText:
                'Contoh: Saya perlu mencatat stok bahan baku yang menipis.',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Minta AI buatkan'),
          ),
        ),
      ],
    ),
  );
}
