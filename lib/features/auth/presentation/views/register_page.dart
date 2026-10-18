import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_async_button.dart';
import '../../../../core/utils/indonesian_phone.dart';
import '../controllers/auth_controller.dart';
import 'auth_scaffold.dart';
import 'auth_validators.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final rawPhone = _phoneController.text.trim();
    final phone = rawPhone.isEmpty ? null : normalizeIndonesianPhone(rawPhone);
    if (rawPhone.isNotEmpty && phone == null) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          fullName: _nameController.text,
          email: _emailController.text,
          phoneE164: phone,
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
    } else if (result.signedIn) {
      context.go('/account');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun dibuat. Periksa email untuk melanjutkan.'),
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    return AuthScaffold(
      title: 'Buat Akun',
      subtitle: 'Gunakan email untuk masuk ke akun Anda.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama lengkap',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Nama lengkap wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [_IndonesianPhoneInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Nomor HP (opsional)',
                hintText: '81234567890',
                helperText: 'Boleh dikosongkan.',
                prefixText: '+62 ',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: validateOptionalIndonesianPhone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kata sandi',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: validateStrongPassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi kata sandi',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) => value != _passwordController.text
                  ? 'Konfirmasi kata sandi tidak sama.'
                  : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'Gunakan minimal 8 karakter dengan huruf besar, huruf kecil, dan angka.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 24),
            AppAsyncButton(
              label: 'Daftar',
              isLoading: isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: isLoading ? null : () => context.go('/login'),
              child: const Text('Sudah punya akun? Masuk'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Field selalu menampilkan nomor nasional setelah +62. Paste `0812…`,
/// `62812…`, dan `+62812…` semuanya berubah menjadi `812…` di layar.
class _IndonesianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith('62')) digits = digits.substring(2);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
