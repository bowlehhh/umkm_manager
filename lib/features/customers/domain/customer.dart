class Customer {
  const Customer({
    required this.id,
    required this.businessId,
    required this.name,
    required this.isActive,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
    isActive: json['is_active'] as bool? ?? true,
  );

  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
}

class CustomerTransactionSummary {
  const CustomerTransactionSummary({
    required this.id,
    required this.invoiceNumber,
    required this.total,
    required this.createdAt,
    required this.paymentStatus,
  });

  factory CustomerTransactionSummary.fromJson(Map<String, dynamic> json) =>
      CustomerTransactionSummary(
        id: json['id'] as String,
        invoiceNumber: json['invoice_number'] as String,
        total: json['total'] as int,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        paymentStatus: json['payment_status'] as String,
      );

  final String id;
  final String invoiceNumber;
  final int total;
  final DateTime createdAt;
  final String paymentStatus;
}

class CustomerDebtSummary {
  const CustomerDebtSummary({
    required this.remainingAmount,
    required this.openCount,
  });

  final int remainingAmount;
  final int openCount;
}
