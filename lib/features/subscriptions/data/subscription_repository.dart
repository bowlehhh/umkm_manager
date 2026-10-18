import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';

class SubscriptionRepository {
  const SubscriptionRepository(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> plans() async =>
      (await _client
              .from('subscription_plans')
              .select('key, label, monthly_price, ai_quota')
              .eq('is_public', true)
              .eq('is_active', true)
              .order('monthly_price'))
          .map(Map<String, dynamic>.from)
          .toList(growable: false);

  Future<List<Map<String, dynamic>>> invoices() async =>
      (await _client
              .from('subscription_invoices')
              .select(
                'id, invoice_number, plan_label_snapshot, price_snapshot, quota_snapshot, status, created_at, expires_at, paid_at',
              )
              .order('created_at', ascending: false)
              .limit(20))
          .map(Map<String, dynamic>.from)
          .toList(growable: false);

  Future<Map<String, dynamic>> instructions() async =>
      Map<String, dynamic>.from(
        await _client
            .from('billing_instructions')
            .select('instructions')
            .eq('id', true)
            .single(),
      );

  Future<void> createInvoice(String planKey) async {
    await _client.rpc(
      'create_subscription_invoice',
      params: {'p_plan_key': planKey},
    );
  }

  Future<void> submitPayment({
    required String invoiceId,
    required String payerName,
    String? reference,
  }) async {
    await _client.rpc(
      'submit_manual_payment',
      params: {
        'p_invoice_id': invoiceId,
        'p_payer_name': payerName.trim(),
        'p_payment_reference': reference?.trim(),
        'p_correlation_id': const Uuid().v4(),
      },
    );
  }
}

final subscriptionRepositoryProvider = Provider(
  (ref) => SubscriptionRepository(ref.watch(supabaseClientProvider)),
);
