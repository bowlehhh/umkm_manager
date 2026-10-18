import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../business_configuration/domain/business_configuration.dart';
import '../../../businesses/data/business_repository.dart';
import '../../../businesses/domain/business.dart';
import '../../data/ai_business_builder_repository.dart';
import '../../data/business_onboarding_repository.dart';
import '../../domain/ai_business_builder_exception.dart';
import '../../domain/business_recommendation_request.dart';

final aiBusinessSetupControllerProvider =
    NotifierProvider<
      AiBusinessSetupController,
      AsyncValue<BusinessConfiguration?>
    >(AiBusinessSetupController.new);

class AiBusinessSetupController
    extends Notifier<AsyncValue<BusinessConfiguration?>> {
  @override
  AsyncValue<BusinessConfiguration?> build() => const AsyncData(null);

  Future<String?> recommend(BusinessRecommendationRequest request) async {
    final normalized = request.toJson();
    final payload = normalized['payload'] as Map<String, dynamic>;
    if ((payload['businessName'] as String).length < 2) {
      return 'Nama usaha minimal 2 karakter.';
    }
    if ((payload['businessType'] as String).isEmpty) {
      return 'Jenis usaha wajib diisi.';
    }
    if (!request.initialSetup &&
        (payload['description'] as String).length < 12) {
      return 'Ceritakan usaha Anda minimal 12 karakter.';
    }
    if ((payload['description'] as String).length > 2000) {
      return 'Deskripsi maksimal 2.000 karakter.';
    }
    if ((payload['additionalNeeds'] as String).length > 500) {
      return 'Kebutuhan tambahan maksimal 500 karakter.';
    }
    state = const AsyncLoading();
    try {
      final config = await ref
          .read(aiBusinessBuilderRepositoryProvider)
          .recommend(request);
      state = AsyncData(config);
      return null;
    } on AiBusinessBuilderException catch (error) {
      state = const AsyncData(null);
      if (_isExpiredSession(error)) {
        await _endExpiredSession();
      }
      return kDebugMode ? '${error.message} (${error.code})' : error.message;
    } on TimeoutException {
      state = const AsyncData(null);
      return 'Waktu rekomendasi habis. Periksa koneksi lalu coba lagi.';
    } on FormatException {
      state = const AsyncData(null);
      return 'Respons AI tidak sesuai format aman. Silakan coba lagi.';
    } on AuthException {
      state = const AsyncData(null);
      await _endExpiredSession();
      return 'Sesi masuk telah berakhir. Silakan masuk kembali.';
    } catch (_) {
      state = const AsyncData(null);
      return 'Rekomendasi belum tersedia. Periksa koneksi atau kuota lalu coba lagi.';
    }
  }

  Future<String?> apply({
    required String name,
    required String typeLabel,
    required BusinessConfiguration configuration,
    String? phone,
    String? address,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(businessOnboardingRepositoryProvider)
          .createBusinessWithConfiguration(
            name: name.trim(),
            type: _databaseType(typeLabel),
            configuration: configuration,
            phone: phone?.trim(),
            address: address?.trim(),
          );
      // RPC sudah membuat usaha, membership aktif, dan konfigurasi dalam satu
      // transaksi. Muat ulang sesi sebelum berpindah agar dashboard langsung
      // membaca usaha aktif dan konfigurasi fitur yang baru dibuat.
      await ref.read(businessSessionProvider.notifier).refresh();
      state = AsyncData(configuration);
      return null;
    } on TimeoutException {
      state = AsyncData(configuration);
      return 'Penerapan konfigurasi membutuhkan waktu terlalu lama. Coba lagi.';
    } on AuthException {
      state = AsyncData(configuration);
      await _endExpiredSession();
      return 'Sesi masuk telah berakhir. Silakan masuk kembali.';
    } on PostgrestException catch (error) {
      state = AsyncData(configuration);
      if (_isSessionPostgrestError(error)) {
        await _endExpiredSession();
        return 'Sesi masuk telah berakhir. Silakan masuk kembali.';
      }
      if (error.code == '42883' ||
          error.message.contains(
            'create_business_with_owner_and_configuration',
          )) {
        return 'Fungsi database untuk menerapkan konfigurasi belum tersedia. Jalankan migration Supabase terbaru terlebih dahulu.';
      }
      return kDebugMode
          ? 'Konfigurasi belum dapat diterapkan. ${error.message}'
          : 'Konfigurasi belum dapat diterapkan. Silakan coba lagi.';
    } catch (_) {
      state = AsyncData(configuration);
      return 'Konfigurasi belum dapat diterapkan. Silakan coba lagi.';
    }
  }

  BusinessType _databaseType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('kuliner') || lower.contains('makan')) {
      return BusinessType.culinary;
    }
    if (lower.contains('fashion')) return BusinessType.fashion;
    if (lower.contains('retail') || lower.contains('toko')) {
      return BusinessType.retail;
    }
    if (lower.contains('fotografi') ||
        lower.contains('salon') ||
        lower.contains('laundry') ||
        lower.contains('bengkel') ||
        lower.contains('jasa') ||
        lower.contains('rental')) {
      return BusinessType.service;
    }
    return BusinessType.other;
  }

  bool _isExpiredSession(AiBusinessBuilderException error) =>
      error.code == 'FUNCTION_AUTH_ERROR' || error.code == 'UNAUTHORIZED';

  bool _isSessionPostgrestError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST301' ||
        message.contains('jwt expired') ||
        message.contains('not authenticated') ||
        message.contains('invalid jwt');
  }

  Future<void> _endExpiredSession() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // signOut Supabase sudah menghapus sesi lokal sebelum request ke server.
      // Router tetap menerima event signedOut dan akan menuju halaman login.
    }
  }
}
