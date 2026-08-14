import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sales_transaction.dart';
import 'transaction_repository.dart';

class SupabaseTransactionRepository implements TransactionRepository {
  const SupabaseTransactionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SalesTransaction>> getTransactions(String businessId) async {
    final data = await _client
        .from('transactions')
        .select('id, invoice_number, total, payment_method, created_at')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(50);
    return data
        .map((item) => SalesTransaction.fromJson(item))
        .toList(growable: false);
  }

  @override
  Future<SalesTransaction> getTransactionDetail({
    required String businessId,
    required String transactionId,
  }) async {
    final data = await _client
        .from('transactions')
        .select('''
          id, invoice_number, subtotal, discount_amount, total, amount_paid,
          change_amount, payment_method, payment_status, created_at,
          transaction_items(quantity, selling_price_snapshot, discount_amount, subtotal, product:products(name))
        ''')
        .eq('id', transactionId)
        .eq('business_id', businessId)
        .single();
    return SalesTransaction.fromJson(data);
  }

  @override
  Future<SalesTransaction> checkout({
    required String businessId,
    required List<CheckoutLine> items,
    required CheckoutPaymentMethod paymentMethod,
    required int amountPaid,
    int discountAmount = 0,
  }) async {
    final data = await _client.rpc(
      'process_checkout',
      params: {
        'p_business_id': businessId,
        'p_items': items.map((item) => item.toJson()).toList(),
        'p_payment_method': paymentMethod.dbValue,
        'p_amount_paid': amountPaid,
        'p_discount_amount': discountAmount,
      },
    );
    return SalesTransaction.fromJson(data as Map<String, dynamic>);
  }
}
