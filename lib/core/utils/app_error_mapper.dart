import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_strings.dart';
import '../../features/auth/domain/email_verification_required_exception.dart';

abstract final class AppErrorMapper {
  static String message(Object error) {
    if (error is EmailVerificationRequiredException) {
      return 'Email belum terverifikasi. Buka tautan verifikasi di email Anda, lalu masuk kembali.';
    }
    if (error is StateError) return error.message;
    if (error is AuthException) {
      return error.message;
    }
    if (error is PostgrestException) {
      return error.message;
    }
    if (error is StorageException) {
      return error.message;
    }
    if (error is AuthRetryableFetchException) {
      return AppStrings.connectionError;
    }
    return AppStrings.genericError;
  }
}
