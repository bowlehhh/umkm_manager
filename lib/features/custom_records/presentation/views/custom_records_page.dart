import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../business_configuration/domain/business_configuration.dart';
import '../../../businesses/domain/business.dart';
import '../../data/custom_record_repository.dart';

/// Modul aman yang dibentuk dari prompt: namanya boleh disesuaikan AI, tetapi
/// data dan form tetap kontrak aplikasi yang teruji.
class CustomRecordsPage extends ConsumerWidget {
  const CustomRecordsPage({
    super.key,
    required this.business,
    required this.feature,
  });

  final Business business;
  final BusinessFeatureConfig feature;

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CustomRecordForm(businessId: business.id),
    );
    ref.invalidate(customRecordsProvider(business.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(customRecordsProvider(business.id));
    return Scaffold(
      appBar: AppBar(title: Text(feature.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text('Tambah ${feature.name.toLowerCase()}'),
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(customRecordsProvider(business.id)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Muat ulang'),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Belum ada catatan ${feature.name.toLowerCase()}. Tambahkan catatan pertama Anda.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(customRecordsProvider(business.id)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _RecordCard(record: items[index]),
                ),
              ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});
  final CustomRecord record;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.note_alt_outlined),
      title: Text(record.title),
      subtitle: Text(
        [
          '${record.recordDate.day.toString().padLeft(2, '0')}/${record.recordDate.month.toString().padLeft(2, '0')}/${record.recordDate.year}',
          if (record.notes?.isNotEmpty == true) record.notes!,
        ].join('\n'),
      ),
      isThreeLine: record.notes?.isNotEmpty == true,
      trailing: record.amount == null
          ? null
          : Text(
              CurrencyFormatter.rupiah(record.amount!),
              style: Theme.of(context).textTheme.labelLarge,
            ),
    ),
  );
}

class _CustomRecordForm extends ConsumerStatefulWidget {
  const _CustomRecordForm({required this.businessId});
  final String businessId;

  @override
  ConsumerState<_CustomRecordForm> createState() => _CustomRecordFormState();
}

class _CustomRecordFormState extends ConsumerState<_CustomRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(customRecordRepositoryProvider)
          .save(
            businessId: widget.businessId,
            title: _title.text,
            amount: int.tryParse(
              _amount.text.replaceAll(RegExp(r'[^0-9]'), ''),
            ),
            notes: _notes.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catatan belum dapat disimpan. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tambah catatan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama catatan'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Wajib diisi.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal (opsional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
