import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../businesses/domain/business.dart';
import '../data/expense_repository.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key, required this.business});
  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider(business.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Pengeluaran')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(expensesProvider(business.id)),
            icon: const Icon(Icons.refresh),
            label: const Text('Muat ulang'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Belum ada pengeluaran pada usaha ini.'))
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(expensesProvider(business.id)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.description),
                        subtitle: Text(
                          '${item.category} • ${DateFormat('dd/MM/yyyy').format(item.date)}',
                        ),
                        trailing: Text(CurrencyFormatter.rupiah(item.amount)),
                        onTap: () => _edit(context, ref, item),
                        onLongPress: () => _delete(context, ref, item),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Expense? item,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ExpenseDialog(businessId: business.id, expense: item),
    );
    if (saved == true) ref.invalidate(expensesProvider(business.id));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Expense item,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pengeluaran?'),
        content: Text(item.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await ref.read(expenseRepositoryProvider).delete(business.id, item.id);
    ref.invalidate(expensesProvider(business.id));
  }
}

class _ExpenseDialog extends ConsumerStatefulWidget {
  const _ExpenseDialog({required this.businessId, this.expense});
  final String businessId;
  final Expense? expense;
  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = TextEditingController(
      text: widget.expense?.category ?? 'Operasional',
    );
    _description = TextEditingController(
      text: widget.expense?.description ?? '',
    );
    _amount = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );
    _date = widget.expense?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _category.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(expenseRepositoryProvider)
          .save(
            businessId: widget.businessId,
            existing: widget.expense,
            category: _category.text,
            description: _description.text,
            amount: int.parse(_amount.text),
            date: _date,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengeluaran belum dapat disimpan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.expense == null ? 'Catat pengeluaran' : 'Ubah pengeluaran',
    ),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Keterangan'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
              validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                  ? 'Nominal harus lebih dari nol.'
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDate: _date,
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
      ),
    ],
  );

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Wajib diisi.' : null;
}
