import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../biometrics/presentation/controllers/biometric_session_notifier.dart';

class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(biometricSessionNotifierProvider);
    final isSigningOut = ref.watch(authControllerProvider).isLoading;
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final state = notifier.state;
        return Scaffold(
          appBar: AppBar(title: const Text('Keamanan')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (state.availability.isAvailable)
                Card(
                  child: SwitchListTile.adaptive(
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: const Text('Login Biometrik'),
                    subtitle: Text(
                      state.isEnabled
                          ? 'Aktif pada perangkat ini'
                          : 'Verifikasi ${state.availability.actionLabel.toLowerCase()} terlebih dahulu untuk mengaktifkan.',
                    ),
                    value: state.isEnabled,
                    onChanged: state.isLoading
                        ? null
                        : (enabled) async {
                            if (enabled) {
                              await notifier.enableForCurrentAccount();
                            } else {
                              await notifier.disable();
                            }
                          },
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Biometrik tidak tersedia atau belum didaftarkan pada perangkat ini.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (state.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    state.message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Aplikasi tidak menyimpan password atau data sidik jari/wajah. Biometrik hanya membuka sesi Supabase yang masih valid.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Logout akun'),
                subtitle: const Text(
                  'Keluar sepenuhnya. Login berikutnya wajib memakai email dan kata sandi.',
                ),
                enabled: !isSigningOut,
                onTap: isSigningOut
                    ? null
                    : () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout akun?'),
        content: const Text(
          'Sesi akan dihapus dari perangkat ini. Anda perlu masuk lagi dengan email dan kata sandi.',
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
    if (accepted != true) return;
    final error = await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
