import '../domain/customer.dart';
import 'customer_repository.dart';

class MockCustomerRepository implements CustomerRepository {
  MockCustomerRepository();
  final Map<String, List<Customer>> _items = {};

  List<Customer> _forBusiness(String businessId) => _items.putIfAbsent(
    businessId,
    () => [
      Customer(
        id: 'preview-customer-$businessId',
        businessId: businessId,
        name: 'Pelanggan Contoh',
        phone: '0812-0000-0000',
        notes: 'Data contoh Development Preview.',
        isActive: true,
      ),
    ],
  );

  @override
  Future<List<Customer>> getCustomers(String businessId) async =>
      List.unmodifiable(
        _forBusiness(businessId).where((item) => item.isActive),
      );

  @override
  Future<Customer> getCustomer({
    required String businessId,
    required String customerId,
  }) async =>
      _forBusiness(businessId).firstWhere((item) => item.id == customerId);

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
    final items = _forBusiness(businessId);
    final item = Customer(
      id:
          existing?.id ??
          'preview-customer-${DateTime.now().microsecondsSinceEpoch}',
      businessId: businessId,
      name: name.trim(),
      phone: _nullIfBlank(phone),
      email: _nullIfBlank(email),
      address: _nullIfBlank(address),
      notes: _nullIfBlank(notes),
      isActive: true,
    );
    if (existing == null) {
      items.add(item);
    } else {
      items[items.indexWhere((value) => value.id == existing.id)] = item;
    }
  }

  @override
  Future<void> archiveCustomer({
    required String businessId,
    required String customerId,
  }) async {
    final items = _forBusiness(businessId);
    final index = items.indexWhere((item) => item.id == customerId);
    if (index < 0) return;
    final item = items[index];
    items[index] = Customer(
      id: item.id,
      businessId: item.businessId,
      name: item.name,
      phone: item.phone,
      email: item.email,
      address: item.address,
      notes: item.notes,
      isActive: false,
    );
  }

  @override
  Future<List<CustomerTransactionSummary>> getTransactions({
    required String businessId,
    required String customerId,
  }) async => const [];

  @override
  Future<CustomerDebtSummary> getDebtSummary({
    required String businessId,
    required String customerId,
  }) async => const CustomerDebtSummary(remainingAmount: 0, openCount: 0);

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
