import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/customer.dart';
import 'customer_repository.dart';

class SupabaseCustomerRepository implements CustomerRepository {
  const SupabaseCustomerRepository(this._client);
  final SupabaseClient _client;

  static const _pageSize = 30;
  static const _listColumns =
      'id, business_id, name, phone, email, is_active, created_at';
  static const _detailColumns =
      'id, business_id, name, phone, email, address, notes, is_active';

  @override
  Future<CustomerPage> getCustomers({
    required String businessId,
    String search = '',
    CustomerCursor? cursor,
  }) async {
    var request = _client
        .from('customers')
        .select(_listColumns)
        .eq('business_id', businessId)
        .eq('is_active', true);
    final normalizedSearch = _normalizeSearch(search);
    if (normalizedSearch.isNotEmpty) {
      request = request.ilike('search_text', '%$normalizedSearch%');
    }
    if (cursor != null) {
      final timestamp = cursor.createdAt.toUtc().toIso8601String();
      request = request.or(
        'created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.${cursor.id})',
      );
    }
    final data = await request
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(_pageSize + 1);
    final hasMore = data.length > _pageSize;
    final items = data.take(_pageSize).toList(growable: false);
    final last = items.isEmpty ? null : items.last;
    return CustomerPage(
      items: items.map(Customer.fromJson).toList(growable: false),
      nextCursor: hasMore && last != null
          ? CustomerCursor(
              createdAt: DateTime.parse(last['created_at'] as String),
              id: last['id'] as String,
            )
          : null,
    );
  }

  @override
  Future<Customer> getCustomer({
    required String businessId,
    required String customerId,
  }) async {
    final data = await _client
        .from('customers')
        .select(_detailColumns)
        .eq('id', customerId)
        .eq('business_id', businessId)
        .single();
    return Customer.fromJson(data);
  }

  @override
  Future<void> saveCustomer({
    required String businessId,
    Customer? existing,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final values = <String, dynamic>{
      'business_id': businessId,
      'name': name.trim(),
      'phone': _nullIfBlank(phone),
      'email': _nullIfBlank(email),
      'address': _nullIfBlank(address),
      'notes': _nullIfBlank(notes),
    };
    if (existing == null) {
      await _client.from('customers').insert(values);
      return;
    }
    await _client
        .from('customers')
        .update(values)
        .eq('id', existing.id)
        .eq('business_id', businessId);
  }

  @override
  Future<void> archiveCustomer({
    required String businessId,
    required String customerId,
  }) => _client
      .from('customers')
      .update({'is_active': false})
      .eq('id', customerId)
      .eq('business_id', businessId);

  @override
  Future<List<CustomerTransactionSummary>> getTransactions({
    required String businessId,
    required String customerId,
  }) async {
    final data = await _client
        .from('transactions')
        .select('id, invoice_number, total, created_at, payment_status')
        .eq('business_id', businessId)
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(20);
    return data
        .map(CustomerTransactionSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<CustomerDebtSummary> getDebtSummary({
    required String businessId,
    required String customerId,
  }) async {
    final data = await _client
        .from('debts')
        .select('remaining_amount')
        .eq('business_id', businessId)
        .eq('customer_id', customerId)
        .neq('status', 'PAID');
    final amounts = data.map((row) => row['remaining_amount'] as int);
    return CustomerDebtSummary(
      remainingAmount: amounts.fold(0, (total, amount) => total + amount),
      openCount: data.length,
    );
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeSearch(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 @+._-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
