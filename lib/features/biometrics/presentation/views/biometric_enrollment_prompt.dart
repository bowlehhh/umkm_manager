import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/biometric_session_notifier.dart';

class BiometricEnrollmentPrompt extends ConsumerStatefulWidget {
  const BiometricEnrollmentPrompt({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<BiometricEnrollmentPrompt> createState() =>
      _BiometricEnrollmentPromptState();
}

class _BiometricEnrollmentPromptState
    extends ConsumerState<BiometricEnrollmentPrompt> {
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(biometricSessionNotifierProvider);
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final state = notifier.state;
        if (state.shouldOfferEnrollment && !_dialogOpen) {
          _dialogOpen = true;
          notifier.dismissEnrollmentPrompt();
          WidgetsBinding.instance.addPostFrameCallback((_) => _showPrompt());
        }
        return widget.child;
      },
    );
  }

  Future<void> _showPrompt() async {
    if (!mounted) return;
    final notifier = ref.read(biometricSessionNotifierProvider);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktifkan login biometrik?'),
        content: const Text(
          'Setelah memilih Aktifkan, verifikasi sidik jari atau wajah akan diminta oleh Android. Login biometrik baru aktif jika verifikasi berhasil. Password dan data biometrik tidak disimpan aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nanti saja'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
    if (accepted == true) await notifier.enableForCurrentAccount();
    _dialogOpen = false;
  }
}
