class AiBusinessBuilderException implements Exception {
  const AiBusinessBuilderException(this.code, this.message);

  final String code;
  final String message;

  static const _messages = {
    'GEMINI_BAD_REQUEST': 'Permintaan ke layanan AI tidak valid.',
    'GEMINI_AUTH_ERROR': 'Layanan AI belum dapat diautentikasi.',
    'GEMINI_MODEL_NOT_FOUND':
        'Model AI belum tersedia. Konfigurasi layanan perlu diperbarui.',
    'GEMINI_RATE_LIMIT':
        'Kuota AI sementara telah tercapai. Coba lagi beberapa saat.',
    'GEMINI_SERVICE_ERROR':
        'Layanan AI sedang bermasalah. Coba lagi beberapa saat.',
    'GEMINI_TIMEOUT': 'Layanan AI membutuhkan waktu terlalu lama. Coba lagi.',
    'GEMINI_INVALID_RESPONSE':
        'Respons AI tidak sesuai format aman. Silakan coba lagi.',
    'NETWORK_ERROR':
        'Koneksi ke layanan AI gagal. Periksa internet lalu coba lagi.',
    'FUNCTION_AUTH_ERROR': 'Sesi masuk telah berakhir. Silakan masuk kembali.',
    'UNAUTHORIZED': 'Sesi masuk telah berakhir. Silakan masuk kembali.',
    'AI_SERVICE_ERROR': 'Layanan AI belum siap. Coba lagi beberapa saat.',
    'INVALID_INPUT': 'Data usaha belum lengkap.',
  };

  factory AiBusinessBuilderException.fromCode(String? value) {
    final code = _messages.containsKey(value) ? value! : 'GEMINI_SERVICE_ERROR';
    return AiBusinessBuilderException(code, _messages[code]!);
  }

  factory AiBusinessBuilderException.fromStatus(int status) {
    return switch (status) {
      400 => AiBusinessBuilderException.fromCode('GEMINI_BAD_REQUEST'),
      401 || 403 => AiBusinessBuilderException.fromCode('FUNCTION_AUTH_ERROR'),
      404 => AiBusinessBuilderException.fromCode('GEMINI_MODEL_NOT_FOUND'),
      429 => AiBusinessBuilderException.fromCode('GEMINI_RATE_LIMIT'),
      _ => AiBusinessBuilderException.fromCode('GEMINI_SERVICE_ERROR'),
    };
  }

  @override
  String toString() => 'AiBusinessBuilderException($code)';
}
