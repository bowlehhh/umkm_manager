String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email wajib diisi.';
  if (!email.contains('@')) return 'Masukkan alamat email yang valid.';
  return null;
}

String? validatePassword(String? value) {
  if ((value?.length ?? 0) < 8) return 'Kata sandi minimal 8 karakter.';
  return null;
}

String? validateStrongPassword(String? value) {
  final password = value ?? '';
  if (password.length < 8) return 'Kata sandi minimal 8 karakter.';
  if (!RegExp(r'[A-Z]').hasMatch(password) ||
      !RegExp(r'[a-z]').hasMatch(password) ||
      !RegExp(r'[0-9]').hasMatch(password)) {
    return 'Gunakan huruf besar, huruf kecil, dan angka.';
  }
  return null;
}
