import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sales_transaction.dart';
import 'transaction_repository.dart';

class SupabaseTransactionRepository implements TransactionRepository {
  const SupabaseTransactionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<TransactionPage> getTransactions({
    required String businessId,
    TransactionCursor? cursor,
  }) async {
    var request = _client
        .from('transactions')
        .select('id, invoice_number, total, payment_method, created_at')
        .eq('business_id', businessId);
    if (cursor != null) {
      final timestamp = cursor.createdAt.toUtc().toIso8601String();
      request = request.or(
        'created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.${cursor.id})',
      );
    }
    final data = await request
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(51);
    final hasMore = data.length > 50;
    final items = data.take(50).toList(growable: false);
    final last = items.isEmpty ? null : items.last;
    return TransactionPage(
      items: items
          .map((item) => SalesTransaction.fromJson(item))
          .toList(growable: false),
      nextCursor: hasMore && last != null
          ? TransactionCursor(
              createdAt: DateTime.parse(last['created_at'] as String),
              id: last['id'] as String,
            )
          : null,
    );
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
          transaction_items(product_name_snapshot, quantity, selling_price_snapshot, discount_amount, subtotal)
        ''')
        .eq('id', transactionId)
        .eq('business_id', businessId)
        .single();
    return SalesTransaction.fromJson(data);
  }

  @override
  Future<SalesTransaction> checkout({
    required String businessId,
    required String requestId,
    required List<CheckoutLine> items,
    required CheckoutPaymentMethod paymentMethod,
    required int amountPaid,
    String? customerId,
    int discountAmount = 0,
  }) async {
    final data = await _client.rpc(
      'process_checkout',
      params: {
        'p_business_id': businessId,
        'p_items': items.map((item) => item.toJson()).toList(),
        'p_payment_method': paymentMethod.dbValue,
        'p_amount_paid': amountPaid,
        'p_customer_id': customerId,
        'p_discount_amount': discountAmount,
        'p_request_id': requestId,
      },
    );
    return SalesTransaction.fromJson(data as Map<String, dynamic>);
  }
}
