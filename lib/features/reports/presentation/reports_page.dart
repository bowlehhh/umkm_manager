import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../businesses/domain/business.dart';
import '../data/report_repository.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, required this.business});
  final Business business;
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late DateTime _start;
  late DateTime _end;
  late Future<BusinessReport> _report;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  void _load() => _report = ref
      .read(reportRepositoryProvider)
      .get(businessId: widget.business.id, start: _start, end: _end);

  Future<void> _pickPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _start,
        end: _end.isAfter(DateTime.now()) ? DateTime.now() : _end,
      ),
    );
    if (range == null) return;
    setState(() {
      _start = range.start;
      _end = range.end;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Laporan usaha')),
    body: FutureBuilder<BusinessReport>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
              label: const Text('Muat ulang laporan'),
            ),
          );
        }
        final report = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            OutlinedButton.icon(
              onPressed: _pickPeriod,
              icon: const Icon(Icons.date_range),
              label: Text(
                '${DateFormat('dd/MM/yyyy').format(_start)} – ${DateFormat('dd/MM/yyyy').format(_end)}',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Laporan ini mencakup penjualan tercatat, HPP snapshot, dan pengeluaran operasional. Modal, pinjaman, serta pengambilan pribadi belum termasuk arus kas.',
            ),
            const SizedBox(height: 16),
            _Metric('Jumlah transaksi', report.transactionCount.toString()),
            _Metric(
              'Penjualan kotor',
              CurrencyFormatter.rupiah(report.grossSales),
            ),
            _Metric('Diskon', CurrencyFormatter.rupiah(report.discounts)),
            _Metric(
              'Penjualan bersih',
              CurrencyFormatter.rupiah(report.netSales),
            ),
            _Metric('HPP', CurrencyFormatter.rupiah(report.cogs)),
            _Metric('Laba kotor', CurrencyFormatter.rupiah(report.grossProfit)),
            _Metric(
              'Pengeluaran operasional',
              CurrencyFormatter.rupiah(report.operatingExpenses),
            ),
            _Metric(
              'Hasil usaha sederhana',
              CurrencyFormatter.rupiah(report.simpleResult),
              emphasized: true,
            ),
            const SizedBox(height: 24),
            Text(
              'Barang/layanan terjual',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (report.items.isEmpty)
              const Text('Belum ada penjualan pada periode ini.')
            else
              ...report.items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text('${item.quantity} terjual'),
                  trailing: Text(CurrencyFormatter.rupiah(item.sales)),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Card(
    color: emphasized ? Theme.of(context).colorScheme.primaryContainer : null,
    child: ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: emphasized ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
    ),
  );
}
