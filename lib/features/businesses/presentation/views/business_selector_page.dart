import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/business_repository.dart';
import '../../domain/business.dart';
import '../controllers/business_setup_controller.dart';

/// Halaman awal setelah masuk untuk memastikan seluruh fitur memakai usaha
/// yang dipilih pengguna.
class BusinessSelectorPage extends ConsumerWidget {
  const BusinessSelectorPage({super.key});

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    Business business,
  ) async {
    if (business.isActive) {
      context.go('/dashboard');
      return;
    }
    final error = await ref
        .read(businessSetupControllerProvider.notifier)
        .selectBusiness(business.id);
    if (!context.mounted) return;
    if (error == null) {
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessesProvider);
    final isLoading = ref.watch(businessSetupControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih usaha')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : () => context.push('/businesses/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah usaha'),
      ),
      body: businesses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () =>
                ref.read(businessSessionProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyBusinesses();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final business = items[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: isLoading
                      ? null
                      : () => _select(context, ref, business),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      _iconFor(business.type),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(business.name),
                  subtitle: Text(
                    '${business.type.label} • ${business.role.label}',
                  ),
                  trailing: business.isActive
                      ? const Chip(label: Text('Dipilih'))
                      : const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Menentukan tujuan awal setelah login berdasarkan membership dan usaha aktif.
class BusinessFlowPage extends ConsumerWidget {
  const BusinessFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(businessSessionProvider);
    return session.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: () =>
                ref.read(businessSessionProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Muat ulang usaha'),
          ),
        ),
      ),
      data: (value) {
        if (!value.hasBusinesses) {
          return const _RedirectPage('/businesses/new');
        }
        final active = value.activeBusiness;
        if (active != null) return const _RedirectPage('/dashboard');
        if (value.businesses.length == 1) {
          return _SelectingOnlyBusinessPage(business: value.businesses.single);
        }
        return const BusinessSelectorPage();
      },
    );
  }
}

class _RedirectPage extends StatefulWidget {
  const _RedirectPage(this.location);
  final String location;

  @override
  State<_RedirectPage> createState() => _RedirectPageState();
}

class _RedirectPageState extends State<_RedirectPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _SelectingOnlyBusinessPage extends ConsumerStatefulWidget {
  const _SelectingOnlyBusinessPage({required this.business});
  final Business business;

  @override
  ConsumerState<_SelectingOnlyBusinessPage> createState() =>
      _SelectingOnlyBusinessPageState();
}

class _SelectingOnlyBusinessPageState
    extends ConsumerState<_SelectingOnlyBusinessPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _select());
  }

  Future<void> _select() async {
    final error = await ref
        .read(businessSetupControllerProvider.notifier)
        .selectBusiness(widget.business.id);
    if (!mounted) return;
    if (error == null) {
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _EmptyBusinesses extends StatelessWidget {
  const _EmptyBusinesses();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 56),
          const SizedBox(height: 16),
          Text(
            'Belum ada usaha',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Buat usaha pertama Anda untuk mulai mengelola penjualan.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/businesses/new'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat usaha'),
          ),
        ],
      ),
    ),
  );
}

IconData _iconFor(BusinessType type) => switch (type) {
  BusinessType.culinary => Icons.restaurant_rounded,
  BusinessType.service => Icons.handyman_outlined,
  BusinessType.fashion => Icons.checkroom_outlined,
  BusinessType.retail || BusinessType.other => Icons.storefront_outlined,
};
