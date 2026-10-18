import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class UserProfile {
  const UserProfile({required this.displayName, required this.phoneVerified});
  final String displayName;
  final bool phoneVerified;
  bool get isComplete => displayName.trim().isNotEmpty;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    displayName: (json['display_name'] ?? json['full_name'] ?? '') as String,
    phoneVerified: json['phone_verified'] as bool? ?? false,
  );
}

class ProfileRepository {
  const ProfileRepository(this._client);
  final SupabaseClient _client;
  Future<UserProfile> getCurrent() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sesi masuk telah berakhir.');
    final row = await _client.from('profiles').select().eq('id', id).single();
    return UserProfile.fromJson(row);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
