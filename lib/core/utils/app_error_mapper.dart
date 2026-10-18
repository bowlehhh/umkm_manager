import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_strings.dart';
import '../../features/auth/domain/email_verification_required_exception.dart';
import '../../features/auth/domain/phone_confirmation_required_exception.dart';

abstract final class AppErrorMapper {
  static String message(Object error) {
    if (error is EmailVerificationRequiredException) {
      return 'Email belum terverifikasi. Buka tautan verifikasi di email Anda, lalu masuk kembali.';
    }
    if (error is PhoneConfirmationRequiredException) {
      return 'Verifikasi nomor HP belum diwajibkan oleh server. Aktifkan Confirm phone di Supabase terlebih dahulu.';
    }
    if (error is StateError) return error.message;
    if (error is AuthRetryableFetchException) {
      return AppStrings.connectionError;
    }
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      final code = error.code?.toLowerCase() ?? '';
      if (code == 'phone_provider_disabled') {
        return 'Pendaftaran dengan nomor HP belum diaktifkan. Hubungi pengelola aplikasi.';
      }
      if (code == 'sms_send_failed') {
        return 'Kode SMS belum dapat dikirim. Layanan SMS perlu diperiksa oleh pengelola aplikasi.';
      }
      if (code == 'over_sms_send_rate_limit' ||
          code == 'over_request_rate_limit') {
        return 'Terlalu banyak permintaan kode. Tunggu beberapa menit lalu coba lagi.';
      }
      if (code == 'phone_exists' || code == 'user_already_exists') {
        return 'Nomor HP ini sudah digunakan. Silakan masuk atau gunakan nomor lain.';
      }
      if (code == 'signup_disabled') {
        return 'Pendaftaran akun sedang tidak tersedia. Hubungi pengelola aplikasi.';
      }
      if (code == 'captcha_failed') {
        return 'Pemeriksaan keamanan belum berhasil. Coba lagi beberapa saat.';
      }
      if (code == 'unexpected_failure') {
        return 'Layanan akun sedang bermasalah. Coba lagi nanti atau hubungi pengelola aplikasi.';
      }
      if (message.contains('already registered') ||
          message.contains('already been registered')) {
        return 'Nomor HP atau email ini sudah digunakan.';
      }
      if (message.contains('invalid login') ||
          message.contains('invalid credentials')) {
        return 'Nomor HP/email atau kata sandi belum tepat.';
      }
      if (message.contains('otp') || message.contains('token')) {
        return 'Kode belum benar atau sudah tidak berlaku.';
      }
      if (message.contains('rate limit') || message.contains('too many')) {
        return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
      }
      if (message.contains('sms') ||
          message.contains('phone provider') ||
          message.contains('send failed') ||
          code.contains('sms')) {
        return 'Kode SMS belum dapat dikirim. Pastikan layanan SMS sudah aktif, lalu coba lagi.';
      }
      if (error.statusCode != null &&
          (error.statusCode == '500' ||
              error.statusCode == '502' ||
              error.statusCode == '503')) {
        return 'Layanan pendaftaran sedang belum siap. Coba lagi beberapa saat.';
      }
      return AppStrings.genericError;
    }
    if (error is PostgrestException) {
      return error.message;
    }
    if (error is StorageException) {
      return error.message;
    }
    return AppStrings.genericError;
  }
}
