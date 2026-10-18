class AiBusinessBuilderException implements Exception {
  const AiBusinessBuilderException(this.code, this.message);

  final String code;
  final String message;

  static const _messages = {
    'AI_BAD_REQUEST': 'Permintaan ke layanan AI tidak valid.',
    'AI_PROVIDER_AUTH': 'Layanan AI belum dapat diautentikasi.',
    'AI_MODEL_UNAVAILABLE':
        'Model AI belum tersedia. Konfigurasi layanan perlu diperbarui.',
    'AI_PROVIDER_RATE_LIMIT':
        'Kuota AI sementara telah tercapai. Coba lagi beberapa saat.',
    'AI_PROVIDER_ERROR':
        'Layanan AI sedang bermasalah. Coba lagi beberapa saat.',
    'AI_TIMEOUT': 'Layanan AI membutuhkan waktu terlalu lama. Coba lagi.',
    'AI_INVALID_RESPONSE':
        'Respons AI tidak sesuai format aman. Silakan coba lagi.',
    'NETWORK_ERROR':
        'Koneksi ke layanan AI gagal. Periksa internet lalu coba lagi.',
    'FUNCTION_AUTH_ERROR': 'Sesi masuk telah berakhir. Silakan masuk kembali.',
    'UNAUTHORIZED': 'Sesi masuk telah berakhir. Silakan masuk kembali.',
    'AI_SERVICE_ERROR': 'Layanan AI belum siap. Coba lagi beberapa saat.',
    'OPENAI_API_KEY_MISSING':
        'Konfigurasi layanan OpenAI belum siap. Coba lagi beberapa saat.',
    'SUBSCRIPTION_REQUIRED':
        'Langganan layanan diperlukan untuk menggunakan AI.',
    'AI_QUOTA_EXHAUSTED':
        'Batas penggunaan AI harian Anda telah tercapai. Coba lagi besok.',
    'AI_RATE_LIMITED':
        'Terlalu banyak permintaan AI. Silakan coba kembali sebentar lagi.',
    'INVALID_INPUT': 'Data usaha belum lengkap.',
  };

  factory AiBusinessBuilderException.fromCode(String? value) {
    final code = _messages.containsKey(value) ? value! : 'AI_PROVIDER_ERROR';
    return AiBusinessBuilderException(code, _messages[code]!);
  }

  factory AiBusinessBuilderException.fromStatus(int status) {
    return switch (status) {
      400 => AiBusinessBuilderException.fromCode('AI_BAD_REQUEST'),
      401 || 403 => AiBusinessBuilderException.fromCode('FUNCTION_AUTH_ERROR'),
      402 => AiBusinessBuilderException.fromCode('SUBSCRIPTION_REQUIRED'),
      404 => AiBusinessBuilderException.fromCode('AI_MODEL_UNAVAILABLE'),
      429 => AiBusinessBuilderException.fromCode('AI_PROVIDER_RATE_LIMIT'),
      _ => AiBusinessBuilderException.fromCode('AI_PROVIDER_ERROR'),
    };
  }

  @override
  String toString() => 'AiBusinessBuilderException($code)';
}
