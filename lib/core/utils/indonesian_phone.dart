/// Normalisasi nomor Indonesia yang ditampilkan dan disimpan sebagai E.164.
/// Tidak mencoba menebak nomor negara lain agar identitas akun konsisten.
String? normalizeIndonesianPhone(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+')) digits = digits.substring(1);
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = '62${digits.substring(1)}';
  if (digits.startsWith('8')) digits = '62$digits';
  if (!digits.startsWith('62')) return null;
  final national = digits.substring(2);
  if (!RegExp(r'^8[1-9][0-9]{7,11}$').hasMatch(national)) return null;
  return '+$digits';
}

bool looksLikePhone(String value) =>
    RegExp(r'^[+0-9() .-]+$').hasMatch(value.trim());

String maskPhone(String phone) {
  if (phone.length < 8) return phone;
  return '${phone.substring(0, 6)}••••${phone.substring(phone.length - 3)}';
}
