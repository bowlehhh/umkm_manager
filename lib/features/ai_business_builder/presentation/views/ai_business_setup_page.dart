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
  final _description = TextEditingController();
  final _customType = TextEditingController();
  String _type = _types.first;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _customType.dispose();
    super.dispose();
  }

  Future<void> _recommend() async {
    if (!_formKey.currentState!.validate()) return;
    final actualType = _type == 'Lainnya' ? _customType.text.trim() : _type;
    final error = await ref
        .read(aiBusinessSetupControllerProvider.notifier)
        .recommend(
          BusinessRecommendationRequest(
            businessName: _name.text,
            businessType: actualType,
            description: _description.text,
          ),
        );
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
      return AiRecommendationReviewPage(
        name: _name.text.trim(),
        type: _type == 'Lainnya' ? _customType.text.trim() : _type,
        initial: recommendation,
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
                      'AI Business Builder',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ceritakan usaha Anda. Rekomendasi dapat diedit sebelum diterapkan.',
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _name,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: '1. Nama usaha',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 2
                          ? 'Nama usaha minimal 2 karakter.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '2. Jenis usaha',
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
                      controller: _description,
                      maxLength: 2000,
                      minLines: 5,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: '3. Deskripsikan usaha',
                        hintText:
                            'Ceritakan cara menerima order, pembayaran, stok, karyawan, dan kebutuhan lainnya.',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 12
                          ? 'Deskripsi minimal 12 karakter.'
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
                            : 'Rekomendasikan dengan AI',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'AI hanya menyarankan modul yang sudah didukung aplikasi. Anda selalu menentukan hasil akhirnya.',
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
    required this.initial,
  });
  final String name;
  final String type;
  final BusinessConfiguration initial;
  @override
  ConsumerState<AiRecommendationReviewPage> createState() =>
      _AiRecommendationReviewPageState();
}

class _AiRecommendationReviewPageState
    extends ConsumerState<AiRecommendationReviewPage> {
  late BusinessConfiguration _config = widget.initial;
  final _dp = TextEditingController();
  String? _applyError;
  @override
  void initState() {
    super.initState();
    _dp.text =
        _config.paymentRule.suggestedDownPaymentPercent?.toString() ?? '';
  }

  @override
  void dispose() {
    _dp.dispose();
    super.dispose();
  }

  void _updateFeature(
    BusinessFeatureConfig feature, {
    bool? enabled,
    String? name,
  }) => setState(
    () => _config = _config.copyWith(
      features: _config.features
          .map(
            (item) => item.key == feature.key
                ? item.copyWith(enabled: enabled, name: name)
                : item,
          )
          .toList(),
    ),
  );
  Future<void> _renameFeature(BusinessFeatureConfig feature) async {
    final controller = TextEditingController(text: feature.name);
    final result = await _textDialog('Ganti nama fitur', controller);
    if (result != null && result.isNotEmpty) {
      _updateFeature(feature, name: result);
    }
  }

  Future<void> _addFeature() async {
    final existing = _config.features.map((item) => item.key).toSet();
    final capability = await showModalBottomSheet<BusinessCapability>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: BusinessCapabilityRegistry.all
            .where(
              (item) =>
                  !existing.contains(item.key) && item.template.isImplemented,
            )
            .map(
              (item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.name),
                subtitle: Text(item.description),
                onTap: () => Navigator.pop(context, item),
              ),
            )
            .toList(),
      ),
    );
    if (capability != null) {
      setState(
        () => _config = _config.copyWith(
          features: [
            ..._config.features,
            BusinessFeatureConfig(
              key: capability.key,
              name: capability.name,
              enabled: true,
              reason: 'Ditambahkan manual oleh pengguna.',
              actions: capability.template.actions.toList()..sort(),
            ),
          ],
        ),
      );
    }
  }

  void _removeFeature(BusinessFeatureConfig feature) => setState(
    () => _config = _config.copyWith(
      features: _config.features
          .where((item) => item.key != feature.key)
          .toList(),
    ),
  );

  Future<String?> _textDialog(String title, TextEditingController controller) =>
      showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama'),
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
  Future<void> _addWorkflow() async {
    final controller = TextEditingController();
    final label = await _textDialog('Tambah langkah workflow', controller);
    if (label != null && label.isNotEmpty) {
      setState(
        () => _config = _config.copyWith(
          workflow: [
            ..._config.workflow,
            WorkflowStep(
              key: 'custom_${DateTime.now().microsecondsSinceEpoch}',
              label: label,
              order: _config.workflow.length + 1,
            ),
          ],
        ),
      );
    }
  }

  Future<void> _renameWorkflow(WorkflowStep step) async {
    final controller = TextEditingController(text: step.label);
    final label = await _textDialog('Ganti nama langkah', controller);
    if (label != null && label.isNotEmpty) {
      setState(
        () => _config = _config.copyWith(
          workflow: _config.workflow
              .map(
                (item) =>
                    item.key == step.key ? item.copyWith(label: label) : item,
              )
              .toList(),
        ),
      );
    }
  }

  Future<void> _addCustomField() async {
    final label = TextEditingController();
    final module =
        _config.features.where((item) => item.enabled).firstOrNull?.key ??
        'orders';
    final result = await _textDialog('Nama custom field', label);
    if (result != null && result.isNotEmpty) {
      setState(
        () => _config = _config.copyWith(
          customFields: [
            ..._config.customFields,
            CustomFieldConfig(
              module: module,
              key: 'custom_${DateTime.now().microsecondsSinceEpoch}',
              label: result,
              type: CustomFieldType.text,
              required: false,
            ),
          ],
        ),
      );
    }
  }

  Future<void> _editCustomField(CustomFieldConfig field) async {
    final label = TextEditingController(text: field.label);
    var selectedType = field.type;
    var required = field.required;
    final edited = await showDialog<CustomFieldConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit custom field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomFieldType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipe field'),
                  items: CustomFieldType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedType = value!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wajib diisi'),
                  value: required,
                  onChanged: (value) => setDialogState(() => required = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                field.copyWith(
                  label: label.text.trim(),
                  type: selectedType,
                  required: required,
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (edited != null && edited.label.isNotEmpty) {
      setState(
        () => _config = _config.copyWith(
          customFields: _config.customFields
              .map((item) => item.key == field.key ? edited : item)
              .toList(),
        ),
      );
    }
  }

  Future<void> _apply() async {
    setState(() => _applyError = null);
    final percent = int.tryParse(_dp.text.trim());
    if (_config.paymentRule.supportsDownPayment &&
        (percent == null || percent < 0 || percent > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DP harus antara 0 sampai 100%.')),
      );
      return;
    }
    final config = _config.copyWith(
      paymentRule: _config.paymentRule.copyWith(
        suggestedDownPaymentPercent: percent,
      ),
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
    final enabledFeatures = _config.features
        .where((item) => item.enabled)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Rekomendasi AI untuk Usaha Anda')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(_config.summary),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Fitur yang disarankan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: isLoading ? null : _addFeature,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._config.features.map((feature) {
              final capability = BusinessCapabilityRegistry.byKey(feature.key);
              final template = BusinessCapabilityRegistry.templateFor(
                feature.key,
              );
              return Card(
                child: SwitchListTile(
                  value: feature.enabled,
                  onChanged: isLoading
                      ? null
                      : (value) => _updateFeature(feature, enabled: value),
                  secondary: Icon(capability?.icon ?? Icons.extension_outlined),
                  title: Row(
                    children: [
                      Expanded(child: Text(feature.name)),
                      IconButton(
                        tooltip: 'Ganti nama',
                        onPressed: isLoading
                            ? null
                            : () => _renameFeature(feature),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Hapus fitur',
                        onPressed: isLoading
                            ? null
                            : () => _removeFeature(feature),
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feature.reason),
                      if (template != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Kemampuan: ${feature.actions.join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (template.relations.isNotEmpty)
                          Text(
                            'Terhubung ke: ${template.relations.join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ],
                  ),
                  controlAffinity: ListTileControlAffinity.trailing,
                ),
              );
            }),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Switch menonaktifkan fitur; gunakan ikon tempat sampah untuk menghapusnya.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Workflow', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: isLoading ? null : _addWorkflow,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _config.workflow.length,
              onReorderItem: (oldIndex, newIndex) => setState(() {
                final steps = [..._config.workflow];
                final item = steps.removeAt(oldIndex);
                steps.insert(newIndex, item);
                _config = _config.copyWith(
                  workflow: [
                    for (var i = 0; i < steps.length; i++)
                      steps[i].copyWith(order: i + 1),
                  ],
                );
              }),
              itemBuilder: (context, index) {
                final step = _config.workflow[index];
                return Card(
                  key: ValueKey(step.key),
                  child: ListTile(
                    onTap: isLoading ? null : () => _renameWorkflow(step),
                    leading: const Icon(Icons.drag_handle_rounded),
                    title: Text(step.label),
                    subtitle: Text('Urutan ${index + 1}'),
                    trailing: IconButton(
                      onPressed: isLoading
                          ? null
                          : () => setState(
                              () => _config = _config.copyWith(
                                workflow: _config.workflow
                                    .where((item) => item.key != step.key)
                                    .toList(),
                              ),
                            ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Custom fields',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: isLoading ? null : _addCustomField,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            if (_config.customFields.isEmpty)
              const Text('Belum ada custom field.')
            else
              ..._config.customFields.map(
                (field) => Card(
                  child: ListTile(
                    onTap: isLoading ? null : () => _editCustomField(field),
                    title: Text(field.label),
                    subtitle: Text(
                      '${field.module} • ${field.type.name}${field.required ? ' • wajib' : ''}',
                    ),
                    trailing: IconButton(
                      onPressed: isLoading
                          ? null
                          : () => setState(
                              () => _config = _config.copyWith(
                                customFields: _config.customFields
                                    .where((item) => item.key != field.key)
                                    .toList(),
                              ),
                            ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SwitchListTile(
              value: _config.paymentRule.supportsDownPayment,
              onChanged: isLoading
                  ? null
                  : (value) => setState(
                      () => _config = _config.copyWith(
                        paymentRule: _config.paymentRule.copyWith(
                          supportsDownPayment: value,
                        ),
                      ),
                    ),
              title: const Text('Mendukung DP'),
            ),
            if (_config.paymentRule.supportsDownPayment)
              TextField(
                controller: _dp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'DP awal',
                  suffixText: '%',
                ),
              ),
            if (_config.unsupportedRequirements.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Kebutuhan yang belum didukung',
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
              onPressed: isLoading || enabledFeatures.isEmpty ? null : _apply,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(isLoading ? 'Menerapkan…' : 'Terapkan konfigurasi'),
            ),
            if (_applyError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _applyError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (enabledFeatures.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Aktifkan minimal satu fitur untuk menerapkan konfigurasi.',
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
