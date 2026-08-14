/// Membuat label navigasi bawah tetap terbaca pada layar sempit.
/// Nama lengkap yang dibuat AI tetap ditampilkan di halaman modul dan Lainnya.
abstract final class NavigationLabelFormatter {
  static String compact({
    required String configuredName,
    required String capabilityName,
    int maxLength = 14,
  }) {
    final name = configuredName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (_fits(name, maxLength)) return name;

    final fallback = capabilityName.trim();
    if (_fits(fallback, maxLength)) return fallback;
    return _ellipsize(fallback, maxLength);
  }

  static bool _fits(String value, int maxLength) =>
      value.length <= maxLength && value.split(' ').length <= 2;

  static String _ellipsize(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1).trimRight()}…';
  }
}
