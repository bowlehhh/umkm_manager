import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isSupabaseConfigured) {
    throw StateError('Supabase belum dikonfigurasi.');
  }
  return Supabase.instance.client;
});
