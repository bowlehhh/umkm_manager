abstract final class VoucherFormValidator {
  static String? code(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Kode voucher wajib diisi.';
    if (!RegExp(r'^[A-Za-z0-9_-]{4,64}$').hasMatch(code)) {
      return 'Kode voucher harus 4–64 karakter (huruf, angka, _ atau -).';
    }
    return null;
  }

  static String? required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label wajib diisi.' : null;

  static String? integer(
    String? value,
    String label, {
    int minimum = 1,
    bool optional = false,
  }) {
    if (optional && (value == null || value.trim().isEmpty)) return null;
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < minimum) return '$label harus ≥ $minimum.';
    return null;
  }
}
