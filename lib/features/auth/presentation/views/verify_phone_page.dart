import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/indonesian_phone.dart';
import '../../../../shared/widgets/app_async_button.dart';
import '../../domain/phone_verification.dart';
import '../controllers/auth_controller.dart';
import 'auth_scaffold.dart';

class VerifyPhonePage extends ConsumerStatefulWidget {
  const VerifyPhonePage({super.key, required this.arguments});
  final PhoneVerificationArguments arguments;

  @override
  ConsumerState<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends ConsumerState<VerifyPhonePage> {
  final _codeController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) return;
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 6 angka dari SMS.')),
      );
      return;
    }
    final error = await ref
        .read(authControllerProvider.notifier)
        .verifyPhone(
          phone: widget.arguments.phone,
          token: code,
          contactEmail: widget.arguments.contactEmail,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else if (widget.arguments.purpose ==
        PhoneVerificationPurpose.passwordRecovery) {
      context.go('/reset-password');
    } else {
      context.go('/account');
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    final error = await ref
        .read(authControllerProvider.notifier)
        .sendPhoneOtp(
          widget.arguments.phone,
          shouldCreateUser:
              widget.arguments.purpose == PhoneVerificationPurpose.registration,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      setState(() => _secondsLeft = 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    return AuthScaffold(
      title: 'Masukkan kode',
      subtitle:
          'Kami mengirim kode 6 digit ke\n${maskPhone(widget.arguments.phone)}',
      child: Column(
        children: [
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(labelText: 'Kode dari SMS'),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 20),
          AppAsyncButton(
            label: 'Verifikasi',
            isLoading: loading,
            onPressed: _verify,
          ),
          TextButton(
            onPressed: loading || _secondsLeft > 0 ? null : _resend,
            child: Text(
              _secondsLeft > 0
                  ? 'Kirim ulang kode ($_secondsLeft dtk)'
                  : 'Kirim ulang kode',
            ),
          ),
        ],
      ),
    );
  }
}
