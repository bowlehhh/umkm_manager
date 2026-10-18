class SalesTransaction {
  const SalesTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    this.subtotal,
    this.discountAmount = 0,
    this.amountPaid,
    this.changeAmount = 0,
    this.paymentStatus,
    this.items = const [],
  });

  factory SalesTransaction.fromJson(Map<String, dynamic> json) {
    final rawItems = json['transaction_items'];
    return SalesTransaction(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      total: json['total'] as int,
      paymentMethod: json['payment_method'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      subtotal: json['subtotal'] as int?,
      discountAmount: json['discount_amount'] as int? ?? 0,
      amountPaid: json['amount_paid'] as int?,
      changeAmount: json['change_amount'] as int? ?? 0,
      paymentStatus: json['payment_status'] as String?,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(TransactionLine.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final String id;
  final String invoiceNumber;
  final int total;
  final String paymentMethod;
  final DateTime createdAt;
  final int? subtotal;
  final int discountAmount;
  final int? amountPaid;
  final int changeAmount;
  final String? paymentStatus;
  final List<TransactionLine> items;
}

class TransactionCursor {
  const TransactionCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;
}

class TransactionPage {
  const TransactionPage({required this.items, this.nextCursor});

  final List<SalesTransaction> items;
  final TransactionCursor? nextCursor;

  bool get hasMore => nextCursor != null;
}

class TransactionLine {
  const TransactionLine({
    required this.productName,
    required this.quantity,
    required this.sellingPrice,
    required this.subtotal,
    this.discountAmount = 0,
  });

  factory TransactionLine.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    return TransactionLine(
      productName:
          json['product_name_snapshot'] as String? ??
          (product is Map<String, dynamic>
              ? (product['name'] as String? ?? 'Produk')
              : 'Produk'),
      quantity: json['quantity'] as int,
      sellingPrice: json['selling_price_snapshot'] as int,
      subtotal: json['subtotal'] as int,
      discountAmount: json['discount_amount'] as int? ?? 0,
    );
  }

  final String productName;
  final int quantity;
  final int sellingPrice;
  final int subtotal;
  final int discountAmount;
}

class CheckoutLine {
  const CheckoutLine({required this.productId, required this.quantity});

  final String productId;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
  };
}

enum CheckoutPaymentMethod {
  cash('CASH', 'Tunai'),
  transfer('TRANSFER', 'Transfer'),
  qris('QRIS', 'QRIS');

  const CheckoutPaymentMethod(this.dbValue, this.label);
  final String dbValue;
  final String label;
}
