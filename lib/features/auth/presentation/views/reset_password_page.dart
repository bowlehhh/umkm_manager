import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_async_button.dart';
import '../controllers/auth_controller.dart';
import 'auth_scaffold.dart';
import 'auth_validators.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(_password.text);
    if (!mounted) return;
    if (error == null) {
      context.go('/account');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Buat kata sandi baru',
    subtitle: 'Gunakan kata sandi yang mudah Anda ingat.',
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Kata sandi baru'),
            validator: validateStrongPassword,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Ulangi kata sandi'),
            validator: (v) =>
                v != _password.text ? 'Kata sandi tidak sama.' : null,
          ),
          const SizedBox(height: 24),
          AppAsyncButton(
            label: 'Simpan kata sandi',
            isLoading: ref.watch(authControllerProvider).isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );
}
