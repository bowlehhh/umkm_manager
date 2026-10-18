import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../businesses/domain/business.dart';
import '../../data/transaction_repository.dart';
import '../../domain/sales_transaction.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key, required this.business});

  final Business business;

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _scrollController = ScrollController();
  List<SalesTransaction> _transactions = const [];
  TransactionCursor? _nextCursor;
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
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240) _loadPage();
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
          .read(transactionRepositoryProvider)
          .getTransactions(businessId: widget.business.id, cursor: cursor);
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _transactions = reset
            ? page.items
            : [
                ..._transactions,
                ...page.items.where(
                  (item) =>
                      !_transactions.any((existing) => existing.id == item.id),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _transactions.isEmpty
          ? Center(
              child: FilledButton(
                onPressed: () => _loadPage(reset: true),
                child: const Text('Coba lagi'),
              ),
            )
          : _transactions.isEmpty
          ? const Center(child: Text('Belum ada transaksi'))
          : RefreshIndicator(
              onRefresh: () => _loadPage(reset: true),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _transactions.length + (_nextCursor != null ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == _transactions.length) {
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
                  final transaction = _transactions[index];
                  final time =
                      '${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}';
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await context.push('/transactions/${transaction.id}');
                        if (mounted) await _loadPage(reset: true);
                      },
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt_long_outlined),
                        ),
                        title: Text(transaction.invoiceNumber),
                        subtitle: Text('${transaction.paymentMethod} • $time'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CurrencyFormatter.rupiah(transaction.total),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
