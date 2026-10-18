import 'dart:async';

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
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<Customer> _customers = const [];
  CustomerCursor? _nextCursor;
  Object? _error;
  var _isInitialLoading = true;
  var _isLoadingMore = false;
  var _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future<void>.microtask(() => _loadPage(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240) {
      _loadPage();
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadPage(reset: true),
    );
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (!reset &&
        (_isInitialLoading || _isLoadingMore || _nextCursor == null)) {
      return;
    }
    final requestVersion = ++_requestVersion;
    final cursor = reset ? null : _nextCursor;
    setState(() {
      if (reset) {
        _isInitialLoading = true;
        _error = null;
      } else {
        _isLoadingMore = true;
      }
    });
    try {
      final page = await ref
          .read(customerRepositoryProvider)
          .getCustomers(
            businessId: widget.business.id,
            search: _query,
            cursor: cursor,
          );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _customers = reset
            ? page.items
            : [
                ..._customers,
                ...page.items.where(
                  (item) =>
                      !_customers.any((existing) => existing.id == item.id),
                ),
              ];
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() => _error = error);
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openCustomer(String route) async {
    await context.push(route);
    if (mounted) await _loadPage(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCustomer('/customers/new'),
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
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _customers.isEmpty
                ? _CustomerFailure(onRetry: () => _loadPage(reset: true))
                : _customers.isEmpty
                ? _CustomerEmpty(
                    hasQuery: _query.isNotEmpty,
                    onAdd: () => _openCustomer('/customers/new'),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadPage(reset: true),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount:
                          _customers.length + (_nextCursor != null ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == _customers.length) {
                          return Center(
                            child: _isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(),
                                  )
                                : TextButton(
                                    onPressed: _loadPage,
                                    child: const Text('Muat lebih banyak'),
                                  ),
                          );
                        }
                        final customer = _customers[index];
                        return _CustomerCard(
                          customer: customer,
                          onTap: () =>
                              _openCustomer('/customers/${customer.id}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
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
