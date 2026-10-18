import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/customer_repository.dart';
import '../../domain/customer.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({super.key, required this.businessId, this.customer});
  final String businessId;
  final Customer? customer;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class CustomerEditPage extends ConsumerWidget {
  const CustomerEditPage({
    super.key,
    required this.businessId,
    required this.customerId,
  });

  final String businessId;
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (businessId: businessId, customerId: customerId);
    return ref
        .watch(customerProvider(key))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Edit Pelanggan')),
            body: Center(
              child: FilledButton.icon(
                onPressed: () => ref.invalidate(customerProvider(key)),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ),
          ),
          data: (customer) =>
              CustomerFormPage(businessId: businessId, customer: customer),
        );
  }
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.customer;
    _name = TextEditingController(text: item?.name ?? '');
    _phone = TextEditingController(text: item?.phone ?? '');
    _email = TextEditingController(text: item?.email ?? '');
    _address = TextEditingController(text: item?.address ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _email, _address, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .saveCustomer(
            businessId: widget.businessId,
            existing: widget.customer,
            name: _name.text,
            phone: _phone.text,
            email: _email.text,
            address: _address.text,
            notes: _notes.text,
          );
      if (widget.customer != null) {
        ref.invalidate(
          customerProvider((
            businessId: widget.businessId,
            customerId: widget.customer!.id,
          )),
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pelanggan belum dapat disimpan. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.customer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan',
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama pelanggan wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (opsional)'),
              validator: (value) {
                final text = value?.trim() ?? '';
                return text.isEmpty ||
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                    ? null
                    : 'Format email tidak valid.';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Alamat (opsional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan…' : 'Simpan pelanggan'),
            ),
          ],
        ),
      ),
    ),
  );
}
