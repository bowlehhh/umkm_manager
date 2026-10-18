import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    category: json['category'] as String,
    description: json['description'] as String,
    amount: json['amount'] as int,
    date: DateTime.parse(json['expense_date'] as String),
  );

  final String id;
  final String category;
  final String description;
  final int amount;
  final DateTime date;
}

class ExpenseRepository {
  const ExpenseRepository(this._client);
  final SupabaseClient _client;

  Future<List<Expense>> list(String businessId) async {
    final rows = await _client
        .from('expenses')
        .select('id, category, description, amount, expense_date')
        .eq('business_id', businessId)
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map(Expense.fromJson).toList(growable: false);
  }

  Future<void> save({
    required String businessId,
    Expense? existing,
    required String category,
    required String description,
    required int amount,
    required DateTime date,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sesi login sudah berakhir.');
    final values = {
      'business_id': businessId,
      'category': category.trim(),
      'description': description.trim(),
      'amount': amount,
      'expense_date': date.toIso8601String().substring(0, 10),
      'created_by': userId,
    };
    if (existing == null) {
      await _client.from('expenses').insert(values);
    } else {
      await _client
          .from('expenses')
          .update(values..remove('created_by'))
          .eq('id', existing.id)
          .eq('business_id', businessId);
    }
  }

  Future<void> delete(String businessId, String id) => _client
      .from('expenses')
      .delete()
      .eq('id', id)
      .eq('business_id', businessId);
}

final expenseRepositoryProvider = Provider(
  (ref) => ExpenseRepository(ref.watch(supabaseClientProvider)),
);
final expensesProvider = FutureProvider.family<List<Expense>, String>(
  (ref, businessId) => ref.watch(expenseRepositoryProvider).list(businessId),
);
