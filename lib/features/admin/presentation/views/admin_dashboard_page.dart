import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../entitlements/data/entitlement_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/admin_repository.dart';
import '../../domain/voucher_form_validator.dart';

class AdminGatePage extends ConsumerStatefulWidget {
  const AdminGatePage({super.key});

  @override
  ConsumerState<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends ConsumerState<AdminGatePage> {
  late final Future<bool> _allowed = _check();

  Future<bool> _check() async =>
      (await ref.read(entitlementServiceProvider).getCurrentEntitlement())
          .isAdmin;

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _allowed,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!snapshot.data!) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/businesses');
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const AdminDashboardPage();
    },
  );
}

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _tab = 0;
  Widget? _morePage;

  void _openMore(Widget page) {
    Navigator.pop(context);
    setState(() => _morePage = page);
  }

  @override
  Widget build(BuildContext context) {
    final isSigningOut = ref.watch(authControllerProvider).isLoading;
    final pages = [
      const _MetricsPage(),
      const _UsersPage(),
      const _VouchersPage(),
      const _AiUsagePage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_morePage == null ? 'Admin ikam' : 'Admin ikam • Lainnya'),
        leading: _morePage == null
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu admin',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : IconButton(
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _morePage = null),
              ),
        actions: [
          IconButton(
            tooltip: 'Kembali ke aplikasi usaha',
            onPressed: () => context.go('/businesses'),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: isSigningOut ? null : _confirmSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Text(
                  'Control Center Admin',
                  style: TextStyle(fontSize: 22),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.card_membership_outlined),
                title: const Text('Subscription'),
                onTap: () => _openMore(const _SubscriptionsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Verifikasi pembayaran'),
                onTap: () => _openMore(const _PaymentSubmissionsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: const Text('Undangan'),
                onTap: () => _openMore(const _InvitationsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.store_outlined),
                title: const Text('Usaha'),
                onTap: () => _openMore(const _BusinessesPage()),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Error / Bug'),
                onTap: () => _openMore(const _ErrorLogsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Audit Log'),
                onTap: () => _openMore(const _AuditLogsPage()),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () => _openMore(const _AdminSettingsPage()),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Logout akun',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('Keluar dari sesi admin di perangkat ini'),
                enabled: !isSigningOut,
                onTap: isSigningOut
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await _confirmSignOut();
                      },
              ),
            ],
          ),
        ),
      ),
      body: _morePage ?? IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _morePage == null
          ? NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (value) => setState(() => _tab = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'User',
                ),
                NavigationDestination(
                  icon: Icon(Icons.confirmation_number_outlined),
                  selectedIcon: Icon(Icons.confirmation_number),
                  label: 'Voucher',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_graph_outlined),
                  selectedIcon: Icon(Icons.auto_graph),
                  label: 'AI Usage',
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _confirmSignOut() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout dari akun admin?'),
        content: const Text(
          'Sesi admin akan dihapus dari perangkat ini. Anda perlu login lagi untuk membuka Control Center.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    final error = await ref.read(authControllerProvider.notifier).signOut();
    if (mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _MetricsPage extends ConsumerWidget {
  const _MetricsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _RefreshableFuture(
    load: ref.read(adminRepositoryProvider).dashboard,
    builder: (context, data) {
      final ai = data['ai'] is Map
          ? Map<String, dynamic>.from(data['ai'] as Map)
          : const <String, dynamic>{};
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ringkasan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric('Total user', data['total_users']),
              _Metric('User aktif 30 hari', data['active_users_30d']),
              _Metric('Usaha', data['total_businesses']),
              _Metric('Subscription aktif', data['active_subscriptions']),
              _Metric('Invoice belum dibayar', data['unpaid_invoices']),
              _Metric('Menunggu verifikasi', data['pending_payments']),
              _Metric('Promosi aktif', data['active_promotions']),
              _Metric('Kuota terpakai', data['ai_quota_used']),
              _Metric(
                'Kuota tersedia',
                (data['ai_quota_allocated'] as num? ?? 0) -
                    (data['ai_quota_used'] as num? ?? 0),
              ),
              _Metric('Undangan aktif', data['active_invitations']),
              _Metric('AI hari ini', ai['today_requests']),
              _Metric('AI bulan ini', ai['month_requests']),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            data['active_users_definition'] as String? ??
                'Aktivitas 30 hari terakhir.',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text(
                '${data['provider'] ?? '-'} • ${data['model'] ?? '-'}',
              ),
              subtitle: Text(
                'Limit harian ${data['daily_ai_limit'] ?? '-'} • rate ${data['rate_limit_per_minute'] ?? '-'}/menit',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Detail metrik control center'),
            children: [
              ...data.entries
                  .where((entry) => entry.key != 'ai')
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      title: Text(entry.key),
                      trailing: Text('${entry.value ?? 0}'),
                    ),
                  ),
              ...ai.entries.map(
                (entry) => ListTile(
                  dense: true,
                  title: Text('AI • ${entry.key}'),
                  trailing: Text('${entry.value ?? 0}'),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _UsersPage extends ConsumerStatefulWidget {
  const _UsersPage();

  @override
  ConsumerState<_UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<_UsersPage> {
  late Future<List<Map<String, dynamic>>> _users = _load();
  String _search = '';
  String? _status;

  Future<List<Map<String, dynamic>>> _load() =>
      ref.read(adminRepositoryProvider).users(search: _search, status: _status);

  void _refresh() => setState(() => _users = _load());

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: const InputDecoration(
            labelText: 'Cari nama atau email',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            _search = value;
            _refresh();
          },
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12, right: 12),
        child: Row(
          children: [
            for (final status in <String?>[
              null,
              'ACTIVE',
              'EXPIRED',
              'NO_ACCESS',
              'DISABLED',
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status ?? 'Semua'),
                  selected: _status == status,
                  onSelected: (_) {
                    setState(() => _status = status);
                    _refresh();
                  },
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _users,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final user = snapshot.data![index];
                  final enabled = user['access_enabled'] as bool? ?? false;
                  return ListTile(
                    onTap: () => _showDetail(user),
                    title: Text(user['name'] as String? ?? 'Tanpa nama'),
                    subtitle: Text(
                      '${user['email'] ?? '-'}\n${user['role'] ?? 'user'} • ${user['access_status'] ?? 'NO_ACCESS'} • ${user['business_count'] ?? 0} usaha',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        final repository = ref.read(adminRepositoryProvider);
                        if (action == 'role') {
                          await repository.setUserRole(
                            user['id'] as String,
                            user['role'] == 'admin' ? 'user' : 'admin',
                          );
                        } else {
                          await repository.setUserAccess(
                            user['id'] as String,
                            !enabled,
                          );
                        }
                        _refresh();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'role',
                          child: Text(
                            user['role'] == 'admin'
                                ? 'Jadikan user'
                                : 'Jadikan admin',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'access',
                          child: Text(
                            enabled ? 'Nonaktifkan akses' : 'Aktifkan akses',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );

  Future<void> _showDetail(Map<String, dynamic> user) async {
    final detail = await ref
        .read(adminRepositoryProvider)
        .userDetail(user['id'] as String);
    if (!mounted) return;
    final profile = detail['profile'] is Map
        ? Map<String, dynamic>.from(detail['profile'] as Map)
        : const <String, dynamic>{};
    final subscription = detail['subscription'] is Map
        ? Map<String, dynamic>.from(detail['subscription'] as Map)
        : const <String, dynamic>{};
    final ai = detail['ai_usage'] is Map
        ? Map<String, dynamic>.from(detail['ai_usage'] as Map)
        : const <String, dynamic>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              profile['name'] as String? ?? 'Detail user',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(profile['email'] as String? ?? '-'),
            const SizedBox(height: 16),
            _DetailSection('Akses', [
              'Role: ${profile['role'] ?? '-'}',
              'Access enabled: ${profile['access_enabled'] ?? false}',
            ]),
            _DetailSection('Subscription', [
              '${subscription['status'] ?? 'NO_ACCESS'} • ${subscription['plan_key'] ?? '-'}',
              'Source: ${subscription['source'] ?? '-'}',
              'Berakhir: ${subscription['expires_at'] ?? '-'}',
              'Voucher: ${subscription['voucher_label'] ?? '-'}',
            ]),
            _DetailSection('AI usage', [
              '${ai['request_count'] ?? 0} request • USD ${ai['estimated_cost_usd'] ?? 0}',
              'Terakhir: ${ai['last_request'] ?? '-'}',
            ]),
            _DetailSection('Riwayat voucher', [
              '${detail['voucher_history'] ?? '[]'}',
            ]),
            _DetailSection('Usaha', ['${detail['businesses'] ?? '[]'}']),
          ],
        ),
      ),
    );
  }
}

class _VouchersPage extends ConsumerStatefulWidget {
  const _VouchersPage();

  @override
  ConsumerState<_VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends ConsumerState<_VouchersPage> {
  late Future<List<Map<String, dynamic>>> _vouchers = _load();
  String _search = '';
  String? _status;
  Future<List<Map<String, dynamic>>> _load() =>
      ref.read(adminRepositoryProvider).vouchers();
  void _refresh() => setState(() => _vouchers = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Text('Buat voucher'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _vouchers,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _RetryState(onRetry: _refresh);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final vouchers = snapshot.data!
            .where(
              (voucher) =>
                  _status == null || voucher['status']?.toString() == _status,
            )
            .where(
              (voucher) =>
                  _search.isEmpty ||
                  (voucher['label']?.toString().toLowerCase().contains(
                        _search.toLowerCase(),
                      ) ??
                      false),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Cari voucher',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value.trim()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final status in <String?>[
                      null,
                      'active',
                      'inactive',
                      'expired',
                      'revoked',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status ?? 'Semua'),
                          selected: _status == status,
                          onSelected: (_) => setState(() => _status = status),
                        ),
                      ),
                  ],
                ),
              ),
              if (vouchers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Voucher tidak ditemukan.')),
                ),
              ...vouchers.map(
                (voucher) => Card(
                  child: ListTile(
                    onTap: () => _showRedemptions(voucher),
                    title: Text(voucher['label'] as String? ?? 'Voucher'),
                    subtitle: Text(
                      '${voucher['status']} • ${voucher['redemption_count']}/${voucher['max_redemptions']} dipakai • sisa ${(voucher['max_redemptions'] as int? ?? 0) - (voucher['redemption_count'] as int? ?? 0)}\n${voucher['duration_days'] ?? '-'} hari • AI ${voucher['ai_quota'] ?? 'default'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (status) async {
                        await ref
                            .read(adminRepositoryProvider)
                            .setVoucherStatus(voucher['id'] as String, status);
                        _refresh();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'active', child: Text('Aktifkan')),
                        PopupMenuItem(
                          value: 'inactive',
                          child: Text('Nonaktifkan'),
                        ),
                        PopupMenuItem(value: 'revoked', child: Text('Revoke')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateVoucherDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voucher berhasil dibuat.')));
      _refresh();
    }
  }

  Future<void> _showRedemptions(Map<String, dynamic> voucher) async {
    final items = await ref
        .read(adminRepositoryProvider)
        .voucherRedemptions(voucher['id'] as String);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Redeem ${voucher['label'] ?? 'voucher'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const ListTile(title: Text('Belum ada user yang redeem.')),
          ...items.map(
            (item) => ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(item['name'] as String? ?? 'Tanpa nama'),
              subtitle: Text(
                '${item['email'] ?? '-'}\n${item['redeemed_at'] ?? '-'} • berakhir ${item['expires_at'] ?? '-'}',
              ),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Data belum dapat dimuat. Periksa koneksi Anda.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

class _CreateVoucherDialog extends ConsumerStatefulWidget {
  const _CreateVoucherDialog();

  @override
  ConsumerState<_CreateVoucherDialog> createState() =>
      _CreateVoucherDialogState();
}

class _CreateVoucherDialogState extends ConsumerState<_CreateVoucherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _label = TextEditingController();
  final _days = TextEditingController(text: '7');
  final _quota = TextEditingController();
  final _max = TextEditingController(text: '1');
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _code.dispose();
    _label.dispose();
    _days.dispose();
    _quota.dispose();
    _max.dispose();
    super.dispose();
  }

  void _normalizeCode(String value) {
    final normalized = value.toUpperCase();
    if (value == normalized) return;
    _code.value = _code.value.copyWith(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final quota = _quota.text.trim().isEmpty ? null : int.parse(_quota.text);
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    FocusScope.of(context).unfocus();
    try {
      await ref
          .read(adminRepositoryProvider)
          .createVoucher(
            code: _code.text,
            label: _label.text,
            durationDays: int.parse(_days.text),
            // Zero is explicitly the plan default, not an ambiguous quota.
            aiQuota: quota == 0 ? null : quota,
            maxRedemptions: int.parse(_max.text),
          );
      if (mounted) Navigator.pop(context, true);
    } on AdminVoucherException catch (error) {
      if (mounted) {
        setState(() => _submitError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _submitError =
              'Voucher belum dapat dibuat. Periksa kode dan hak admin Anda.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 410;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.confirmation_number_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buat voucher',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text(
                            'Atur akses dan batas penggunaan voucher.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _code,
                            enabled: !_submitting,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp('[A-Za-z0-9_-]'),
                              ),
                            ],
                            onChanged: _normalizeCode,
                            validator: VoucherFormValidator.code,
                            decoration: _decoration(
                              'Kode voucher',
                              hint: 'Contoh: UMKM2026',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _label,
                            enabled: !_submitting,
                            validator: (value) =>
                                VoucherFormValidator.required(value, 'Label'),
                            decoration: _decoration(
                              'Label voucher',
                              hint: 'Contoh: Promo pelanggan baru',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (narrow) ...[
                            _durationField(),
                            const SizedBox(height: 12),
                            _maxRedemptionField(),
                          ] else
                            Row(
                              children: [
                                Expanded(child: _durationField()),
                                const SizedBox(width: 12),
                                Expanded(child: _maxRedemptionField()),
                              ],
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _quota,
                            enabled: !_submitting,
                            keyboardType: TextInputType.number,
                            validator: (value) => VoucherFormValidator.integer(
                              value,
                              'Quota AI harian',
                              minimum: 0,
                              optional: true,
                            ),
                            decoration: _decoration(
                              'Quota AI harian (opsional)',
                              hint: 'Kosongkan untuk quota default',
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Isi 0 atau kosong untuk memakai quota default paket.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          if (_submitError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _submitError!,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Menyimpan...'),
                                ],
                              )
                            : const Text('Simpan voucher'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _durationField() => TextFormField(
    controller: _days,
    enabled: !_submitting,
    keyboardType: TextInputType.number,
    validator: (value) => VoucherFormValidator.integer(value, 'Durasi hari'),
    decoration: _decoration('Durasi (hari)'),
  );

  Widget _maxRedemptionField() => TextFormField(
    controller: _max,
    enabled: !_submitting,
    keyboardType: TextInputType.number,
    validator: (value) => VoucherFormValidator.integer(value, 'Maks. redeem'),
    decoration: _decoration('Maks. redeem'),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection(this.title, this.lines);
  final String title;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...lines.map(Text.new),
        ],
      ),
    ),
  );
}

class _AiUsagePage extends ConsumerWidget {
  const _AiUsagePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _RefreshableFuture(
    load: ref.read(adminRepositoryProvider).aiUsage,
    builder: (context, data) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Penggunaan AI', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...data.entries.map(
          (entry) => Card(
            child: ListTile(
              title: Text(entry.key),
              trailing: Text('${entry.value ?? 0}'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AiUsageUsersList(repository: ref.read(adminRepositoryProvider)),
      ],
    ),
  );
}

class _AiUsageUsersList extends StatefulWidget {
  const _AiUsageUsersList({required this.repository});
  final AdminRepository repository;

  @override
  State<_AiUsageUsersList> createState() => _AiUsageUsersListState();
}

class _AiUsageUsersListState extends State<_AiUsageUsersList> {
  int _days = 30;
  late Future<List<Map<String, dynamic>>> _items = _load();
  Future<List<Map<String, dynamic>>> _load() =>
      widget.repository.aiUsageByUser(days: _days);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text('Per user'),
          const Spacer(),
          DropdownButton<int>(
            value: _days,
            items: const [
              DropdownMenuItem(value: 1, child: Text('Hari ini')),
              DropdownMenuItem(value: 7, child: Text('7 hari')),
              DropdownMenuItem(value: 30, child: Text('30 hari')),
            ],
            onChanged: (value) => setState(() {
              _days = value!;
              _items = _load();
            }),
          ),
        ],
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Column(
            children: snapshot.data!
                .map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item['name'] as String? ?? 'Tanpa nama'),
                      subtitle: Text(
                        '${item['email'] ?? '-'} • ${item['success_count'] ?? 0} sukses / ${item['error_count'] ?? 0} error\n${item['total_tokens'] ?? 0} token • USD ${item['estimated_cost_usd'] ?? 0}',
                      ),
                      isThreeLine: true,
                      trailing: Text('${item['request_count'] ?? 0} req'),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _SubscriptionsPage extends ConsumerWidget {
  const _SubscriptionsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _RefreshableRows(
    load: () => ref.read(adminRepositoryProvider).subscriptions(),
    builder: (context, items, refresh) => ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            title: Text(item['name'] as String? ?? 'Tanpa nama'),
            subtitle: Text(
              '${item['email'] ?? '-'}\n${item['status']} • ${item['plan_key'] ?? '-'} • ${item['source'] ?? '-'}\nBerakhir: ${item['expires_at'] ?? '-'} (${item['remaining_days'] ?? 0} hari)',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                final repo = ref.read(adminRepositoryProvider);
                final userId = item['user_id'] as String;
                if (action == 'extend') {
                  await repo.extendSubscription(userId, 30);
                }
                if (action == 'activate') {
                  await repo.activateSubscription(
                    userId: userId,
                    durationDays: 30,
                  );
                }
                if (action == 'cancel' || action == 'revoked') {
                  await repo.setSubscriptionStatus(
                    userId,
                    action == 'cancel' ? 'cancelled' : 'revoked',
                  );
                }
                refresh();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'activate',
                  child: Text('Aktifkan 30 hari'),
                ),
                PopupMenuItem(value: 'extend', child: Text('Tambah 30 hari')),
                PopupMenuItem(value: 'cancel', child: Text('Batalkan')),
                PopupMenuItem(value: 'revoked', child: Text('Revoke')),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _InvitationsPage extends ConsumerStatefulWidget {
  const _InvitationsPage();
  @override
  ConsumerState<_InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends ConsumerState<_InvitationsPage> {
  static const _pageSize = 30;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  String? _status;
  String? _purpose;
  bool _loading = true;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_reload);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool append = false}) async {
    setState(() => _loading = true);
    try {
      final rows = await ref
          .read(adminRepositoryProvider)
          .invitations(
            status: _status,
            purpose: _purpose,
            search: _search.text,
            limit: _pageSize,
            offset: append ? _items.length : 0,
          );
      if (!mounted) return;
      setState(() {
        _items = append ? [..._items, ...rows] : rows;
        _hasMore = rows.length == _pageSize;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final token = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateInvitationDialog(),
    );
    if (!mounted || token == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Simpan token sekarang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Token mentah hanya ditampilkan sekali. Server hanya menyimpan hash dan token ini tidak dapat dipulihkan.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              token,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Token disalin.')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Salin'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Saya sudah menyimpan'),
          ),
        ],
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Text('Buat undangan'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Cari email atau usaha',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _reload(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              DropdownButton<String?>(
                value: _status,
                hint: const Text('Semua status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Semua status')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Aktif')),
                  DropdownMenuItem(value: 'USED', child: Text('Dipakai')),
                  DropdownMenuItem(value: 'REVOKED', child: Text('Dicabut')),
                  DropdownMenuItem(
                    value: 'EXPIRED',
                    child: Text('Kedaluwarsa'),
                  ),
                ],
                onChanged: (value) {
                  _status = value;
                  _reload();
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String?>(
                value: _purpose,
                hint: const Text('Semua tujuan'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Semua tujuan')),
                  DropdownMenuItem(
                    value: 'APP_ACCESS',
                    child: Text('Akses aplikasi'),
                  ),
                  DropdownMenuItem(
                    value: 'BUSINESS_MEMBERSHIP',
                    child: Text('Keanggotaan usaha'),
                  ),
                  DropdownMenuItem(value: 'PROMOTION', child: Text('Promosi')),
                ],
                onChanged: (value) {
                  _purpose = value;
                  _reload();
                },
              ),
            ],
          ),
        ),
        if (_loading && _items.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: _items.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _items.length) {
                    return Center(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => _reload(append: true),
                        child: const Text('Muat lagi'),
                      ),
                    );
                  }
                  final item = _items[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        item['status'] == 'ACTIVE'
                            ? Icons.mark_email_unread
                            : Icons.mark_email_read_outlined,
                      ),
                      title: Text('${item['purpose']} • ${item['status']}'),
                      subtitle: Text(
                        'Email: ${item['email'] ?? 'tidak dibatasi'}\nUsaha: ${item['business_name'] ?? '-'} • role ${item['business_role'] ?? '-'}\nBerakhir: ${item['expires_at']}',
                      ),
                      isThreeLine: true,
                      trailing: item['status'] == 'ACTIVE'
                          ? IconButton(
                              tooltip: 'Cabut undangan',
                              icon: const Icon(Icons.block),
                              onPressed: () async {
                                await ref
                                    .read(adminRepositoryProvider)
                                    .revokeInvitation(item['id'] as String);
                                await _reload();
                              },
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    ),
  );
}

class _CreateInvitationDialog extends ConsumerStatefulWidget {
  const _CreateInvitationDialog();
  @override
  ConsumerState<_CreateInvitationDialog> createState() =>
      _CreateInvitationDialogState();
}

class _CreateInvitationDialogState
    extends ConsumerState<_CreateInvitationDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _businessId = TextEditingController();
  final _quota = TextEditingController(text: '3');
  final _reason = TextEditingController();
  String _purpose = 'APP_ACCESS';
  String _businessRole = 'CASHIER';
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 7));
  DateTime _promotionEndsAt = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _businessId.dispose();
    _quota.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await ref
          .read(adminRepositoryProvider)
          .createInvitation(
            purpose: _purpose,
            expiresAt: _expiresAt,
            email: _email.text,
            businessId: _purpose == 'BUSINESS_MEMBERSHIP'
                ? _businessId.text
                : null,
            businessRole: _purpose == 'BUSINESS_MEMBERSHIP'
                ? _businessRole
                : null,
            promotionEndsAt: _purpose == 'PROMOTION' ? _promotionEndsAt : null,
            promotionQuota: _purpose == 'PROMOTION'
                ? int.tryParse(_quota.text)
                : null,
            reason: _purpose == 'PROMOTION' ? _reason.text : null,
          );
      if (mounted) Navigator.pop(context, token);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Undangan belum dapat dibuat. Periksa data dan coba lagi.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Buat undangan'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _purpose,
              decoration: const InputDecoration(labelText: 'Tujuan'),
              items: const [
                DropdownMenuItem(
                  value: 'APP_ACCESS',
                  child: Text('Akses aplikasi'),
                ),
                DropdownMenuItem(
                  value: 'BUSINESS_MEMBERSHIP',
                  child: Text('Keanggotaan usaha'),
                ),
                DropdownMenuItem(value: 'PROMOTION', child: Text('Promosi AI')),
              ],
              onChanged: (value) => setState(() => _purpose = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Email penerima (opsional)',
              ),
            ),
            if (_purpose == 'BUSINESS_MEMBERSHIP') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _businessId,
                decoration: const InputDecoration(labelText: 'Business ID'),
                validator: (value) => (value?.trim().length ?? 0) == 36
                    ? null
                    : 'Business ID UUID wajib diisi.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _businessRole,
                decoration: const InputDecoration(labelText: 'Role usaha'),
                items: const [
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin usaha')),
                  DropdownMenuItem(value: 'CASHIER', child: Text('Kasir')),
                ],
                onChanged: (value) => _businessRole = value!,
              ),
            ],
            if (_purpose == 'PROMOTION') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _quota,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kuota AI'),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) > 0
                    ? null
                    : 'Kuota wajib lebih dari nol.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Alasan promosi'),
                validator: (value) => (value?.trim().length ?? 0) >= 3
                    ? null
                    : 'Alasan minimal 3 karakter.',
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kedaluwarsa undangan'),
              subtitle: Text(_expiresAt.toLocal().toString()),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 366)),
                  initialDate: _expiresAt,
                );
                if (date != null) {
                  setState(
                    () => _expiresAt = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      23,
                      59,
                    ),
                  );
                }
              },
            ),
            if (_purpose == 'PROMOTION')
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Promosi berakhir'),
                subtitle: Text(_promotionEndsAt.toLocal().toString()),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 366)),
                    initialDate: _promotionEndsAt,
                  );
                  if (date != null) {
                    setState(
                      () => _promotionEndsAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        23,
                        59,
                      ),
                    );
                  }
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
        child: Text(_saving ? 'Membuat…' : 'Buat'),
      ),
    ],
  );
}

class _PaymentSubmissionsPage extends ConsumerWidget {
  const _PaymentSubmissionsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _RefreshableRows(
    load: ref.read(adminRepositoryProvider).paymentSubmissions,
    builder: (context, items, refresh) => items.isEmpty
        ? const Center(child: Text('Tidak ada pembayaran menunggu verifikasi.'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text(
                    '${item['invoice_number']} • ${item['plan_label']}',
                  ),
                  subtitle: Text(
                    '${item['user_name']} (${item['user_email']})\nPengirim: ${item['payer_name']} • Referensi: ${item['payment_reference'] ?? '-'}\nRp${item['amount']} • kuota ${item['quota']}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<bool>(
                    onSelected: (approve) async {
                      await ref
                          .read(adminRepositoryProvider)
                          .reviewPayment(
                            submissionId: item['id'] as String,
                            approve: approve,
                            reason: approve
                                ? null
                                : 'Pembayaran tidak dapat diverifikasi',
                          );
                      refresh();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: true, child: Text('Setujui')),
                      PopupMenuItem(value: false, child: Text('Tolak')),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

class _BusinessesPage extends ConsumerWidget {
  const _BusinessesPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _RefreshableRows(
    load: ref.read(adminRepositoryProvider).businesses,
    builder: (context, items, _) => ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            title: Text(item['name'] as String? ?? 'Usaha'),
            subtitle: Text(
              'Owner: ${item['owner_name'] ?? '-'} (${item['owner_email'] ?? '-'})\n${item['member_count'] ?? 0} anggota • ${item['product_count'] ?? 0} produk • ${item['transaction_count'] ?? 0} transaksi\nFitur: ${item['active_features'] ?? '[]'}',
            ),
            isThreeLine: true,
          ),
        );
      },
    ),
  );
}

class _ErrorLogsPage extends ConsumerWidget {
  const _ErrorLogsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _RefreshableRows(
    load: () => ref.read(adminRepositoryProvider).errorLogs(resolved: false),
    builder: (context, items, refresh) => ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text('${item['feature']} • ${item['error_code']}'),
            subtitle: Text(
              '${item['safe_message']}\n${item['created_at']} • ${item['occurrences']} kejadian',
            ),
            isThreeLine: true,
            trailing: TextButton(
              onPressed: () async {
                await ref
                    .read(adminRepositoryProvider)
                    .setErrorResolved(item['id'] as String, true);
                refresh();
              },
              child: const Text('Selesai'),
            ),
          ),
        );
      },
    ),
  );
}

class _AuditLogsPage extends ConsumerStatefulWidget {
  const _AuditLogsPage();

  @override
  ConsumerState<_AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<_AuditLogsPage> {
  static const _pageSize = 50;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  String? _source;
  bool _loading = true;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    setState(() => _loading = true);
    try {
      final rows = await ref
          .read(adminRepositoryProvider)
          .auditLogs(
            source: _source,
            search: _search.text,
            limit: _pageSize,
            offset: append ? _items.length : 0,
          );
      if (!mounted) return;
      setState(() {
        _items = append ? [..._items, ...rows] : rows;
        _hasMore = rows.length == _pageSize;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Cari actor, aksi, atau resource',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String?>(
              value: _source,
              items: const [
                DropdownMenuItem(value: null, child: Text('Semua')),
                DropdownMenuItem(value: 'PLATFORM', child: Text('Platform')),
                DropdownMenuItem(value: 'BUSINESS', child: Text('Usaha')),
              ],
              onChanged: (value) {
                _source = value;
                _load();
              },
            ),
          ],
        ),
      ),
      if (_loading && _items.isEmpty)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return Center(
                    child: TextButton(
                      onPressed: _loading ? null : () => _load(append: true),
                      child: const Text('Muat lagi'),
                    ),
                  );
                }
                final item = _items[index];
                return Card(
                  child: ListTile(
                    title: Text('${item['source']} • ${item['action']}'),
                    subtitle: Text(
                      '${item['actor_name'] ?? 'Sistem'} • ${item['created_at'] ?? '-'}\n${item['resource_type']}: ${item['resource_id'] ?? '-'} • ${item['result']}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
        ),
    ],
  );
}

class _AdminSettingsPage extends ConsumerWidget {
  const _AdminSettingsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _RefreshableFuture(
    load: ref.read(adminRepositoryProvider).dashboard,
    builder: (context, data) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Settings AI', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 12),
        ListTile(
          title: const Text('Provider aktif'),
          trailing: Text('${data['provider'] ?? '-'}'),
        ),
        ListTile(
          title: const Text('Model aktif'),
          trailing: Text('${data['model'] ?? '-'}'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Konfigurasi provider/model tetap hanya dibaca di sini; secret dan API key tidak pernah dikirim ke Flutter.',
          ),
        ),
      ],
    ),
  );
}

class _RefreshableRows extends StatefulWidget {
  const _RefreshableRows({required this.load, required this.builder});
  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(
    BuildContext context,
    List<Map<String, dynamic>> items,
    VoidCallback refresh,
  )
  builder;

  @override
  State<_RefreshableRows> createState() => _RefreshableRowsState();
}

class _RefreshableRowsState extends State<_RefreshableRows> {
  late Future<List<Map<String, dynamic>>> _future = widget.load();
  void _refresh() => setState(() => _future = widget.load());
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: widget.builder(context, snapshot.data!, _refresh),
          );
        },
      );
}

class _RefreshableFuture extends StatefulWidget {
  const _RefreshableFuture({required this.load, required this.builder});
  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(BuildContext context, Map<String, dynamic> data)
  builder;

  @override
  State<_RefreshableFuture> createState() => _RefreshableFutureState();
}

class _RefreshableFutureState extends State<_RefreshableFuture> {
  late Future<Map<String, dynamic>> _future = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: () async => setState(() => _future = widget.load()),
        child: widget.builder(context, snapshot.data!),
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 164,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              '${value ?? 0}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    ),
  );
}
