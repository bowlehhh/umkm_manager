import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/biometric_session_notifier.dart';

class BiometricLockPage extends ConsumerWidget {
  const BiometricLockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(biometricSessionNotifierProvider);
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final state = notifier.state;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Aplikasi terkunci',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Verifikasi biometrik untuk membuka sesi Supabase yang masih aktif.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (state.isLoading)
                        const CircularProgressIndicator()
                      else if (state.availability.isAvailable)
                        FilledButton.icon(
                          onPressed: () => notifier.unlock(),
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text(state.availability.actionLabel),
                        ),
                      if (state.message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                        },
                        child: const Text('Masuk dengan email dan kata sandi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
