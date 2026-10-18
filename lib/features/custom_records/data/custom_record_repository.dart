import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';

class CustomRecord {
  const CustomRecord({
    required this.id,
    required this.title,
    required this.recordDate,
    this.amount,
    this.notes,
  });

  factory CustomRecord.fromJson(Map<String, dynamic> json) => CustomRecord(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num?)?.toInt(),
    notes: json['notes'] as String?,
    recordDate: DateTime.parse(json['record_date'] as String),
  );

  final String id;
  final String title;
  final int? amount;
  final String? notes;
  final DateTime recordDate;
}

abstract interface class CustomRecordRepository {
  Future<List<CustomRecord>> getRecords(String businessId);
  Future<void> save({
    required String businessId,
    required String title,
    int? amount,
    String? notes,
  });
}

final customRecordRepositoryProvider = Provider<CustomRecordRepository>((ref) {
  if (ref.watch(appConfigProvider).isDevelopmentPreview) {
    return MockCustomRecordRepository();
  }
  return SupabaseCustomRecordRepository(ref.watch(supabaseClientProvider));
});

final customRecordsProvider = FutureProvider.family<List<CustomRecord>, String>(
  (ref, businessId) =>
      ref.watch(customRecordRepositoryProvider).getRecords(businessId),
);

class SupabaseCustomRecordRepository implements CustomRecordRepository {
  const SupabaseCustomRecordRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<CustomRecord>> getRecords(String businessId) async {
    final rows = await _client
        .from('custom_feature_records')
        .select('id, title, amount, notes, record_date')
        .eq('business_id', businessId)
        .eq('feature_key', 'custom_records')
        .order('record_date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => CustomRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> save({
    required String businessId,
    required String title,
    int? amount,
    String? notes,
  }) => _client.from('custom_feature_records').insert({
    'business_id': businessId,
    'feature_key': 'custom_records',
    'title': title.trim(),
    'amount': amount,
    'notes': _blankToNull(notes),
  });

  String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

class MockCustomRecordRepository implements CustomRecordRepository {
  final Map<String, List<CustomRecord>> _records = {};

  @override
  Future<List<CustomRecord>> getRecords(String businessId) async =>
      List.unmodifiable(_records[businessId] ?? const []);

  @override
  Future<void> save({
    required String businessId,
    required String title,
    int? amount,
    String? notes,
  }) async {
    final records = _records.putIfAbsent(businessId, () => []);
    records.insert(
      0,
      CustomRecord(
        id: 'record-${DateTime.now().microsecondsSinceEpoch}',
        title: title.trim(),
        amount: amount,
        notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
        recordDate: DateTime.now(),
      ),
    );
  }
}
