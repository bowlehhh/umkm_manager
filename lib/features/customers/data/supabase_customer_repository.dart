import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/customer.dart';
import 'customer_repository.dart';

class SupabaseCustomerRepository implements CustomerRepository {
  const SupabaseCustomerRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Customer>> getCustomers(String businessId) async {
    final data = await _client
        .from('customers')
        .select()
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name');
    return data.map(Customer.fromJson).toList(growable: false);
  }

  @override
  Future<Customer> getCustomer({
    required String businessId,
    required String customerId,
  }) async {
    final data = await _client
        .from('customers')
        .select()
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
}
