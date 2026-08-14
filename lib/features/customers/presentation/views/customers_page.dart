import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../businesses/domain/business.dart';
import '../../data/customer_repository.dart';
import '../../domain/customer.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key, required this.business});
  final Business business;

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider(widget.business.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/new'),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Tambah pelanggan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama, nomor HP, atau email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: customers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _CustomerFailure(
                onRetry: () =>
                    ref.invalidate(customersProvider(widget.business.id)),
              ),
              data: (items) {
                final filtered = items.where(_matchesQuery).toList();
                if (filtered.isEmpty) {
                  return _CustomerEmpty(
                    hasQuery: _query.isNotEmpty,
                    onAdd: () => context.push('/customers/new'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(customersProvider(widget.business.id)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _CustomerCard(
                      customer: filtered[index],
                      onTap: () =>
                          context.push('/customers/${filtered[index].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesQuery(Customer customer) {
    if (_query.isEmpty) return true;
    return [
      customer.name,
      customer.phone,
      customer.email,
    ].whereType<String>().any((value) => value.toLowerCase().contains(_query));
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});
  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(customer.name.characters.first.toUpperCase()),
      ),
      title: Text(customer.name),
      subtitle: Text(
        [customer.phone, customer.email].whereType<String>().join(' • ').isEmpty
            ? 'Belum ada kontak'
            : [customer.phone, customer.email].whereType<String>().join(' • '),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class _CustomerEmpty extends StatelessWidget {
  const _CustomerEmpty({required this.hasQuery, required this.onAdd});
  final bool hasQuery;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 56),
          const SizedBox(height: 12),
          Text(
            hasQuery ? 'Pelanggan tidak ditemukan' : 'Belum ada pelanggan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'Coba kata kunci lain.'
                : 'Tambahkan pelanggan untuk mencatat kontak dan riwayat transaksi.',
            textAlign: TextAlign.center,
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Tambah pelanggan'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CustomerFailure extends StatelessWidget {
  const _CustomerFailure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Muat ulang pelanggan'),
    ),
  );
}
