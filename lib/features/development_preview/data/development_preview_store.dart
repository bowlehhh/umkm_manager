import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../businesses/domain/business.dart';
import '../../business_configuration/domain/business_configuration.dart';
import '../../categories/domain/category.dart';
import '../../products/domain/product.dart';
import '../../transactions/domain/sales_transaction.dart';

/// Data sementara yang hanya hidup di memori selama Development Preview aktif.
/// Tidak pernah digunakan oleh repository Supabase atau pada mode production.
class DevelopmentPreviewStore {
  final Map<String, BusinessConfiguration> configurations = {};
  final List<Business> businesses = [
    const Business(
      id: 'preview-business',
      name: 'Kedai Nusantara',
      type: BusinessType.culinary,
      address: 'Jl. Merdeka No. 12',
      phone: '0812-3456-7890',
      isActive: true,
    ),
  ];

  Business get business =>
      businesses.firstWhere((business) => business.isActive);

  void activateBusiness(String businessId) {
    final index = businesses.indexWhere(
      (business) => business.id == businessId,
    );
    if (index < 0) return;
    final selected = businesses[index];
    for (var i = 0; i < businesses.length; i++) {
      final business = businesses[i];
      businesses[i] = Business(
        id: business.id,
        name: business.name,
        type: business.type,
        address: business.address,
        phone: business.phone,
        role: business.role,
        isActive: business.id == selected.id,
      );
    }
  }

  final Map<String, List<Category>> _categoriesByBusiness = {
    'preview-business': [
      const Category(id: 'preview-food', name: 'Makanan'),
      const Category(id: 'preview-drink', name: 'Minuman'),
      const Category(id: 'preview-snack', name: 'Camilan'),
    ],
  };

  final Map<String, List<Product>> _productsByBusiness = {
    'preview-business': [
      const Product(
        id: 'preview-product-1',
        name: 'Kopi Susu Gula Aren',
        sku: 'KSGA-001',
        categoryId: 'preview-drink',
        categoryName: 'Minuman',
        purchasePrice: 7000,
        sellingPrice: 18000,
        stock: 24,
        minimumStock: 5,
        unit: 'gelas',
        isActive: true,
      ),
      const Product(
        id: 'preview-product-2',
        name: 'Nasi Goreng Spesial',
        sku: 'NGS-001',
        categoryId: 'preview-food',
        categoryName: 'Makanan',
        purchasePrice: 15000,
        sellingPrice: 30000,
        stock: 8,
        minimumStock: 5,
        unit: 'porsi',
        isActive: true,
      ),
      const Product(
        id: 'preview-product-3',
        name: 'Keripik Pisang Cokelat',
        sku: 'KPC-001',
        categoryId: 'preview-snack',
        categoryName: 'Camilan',
        purchasePrice: 5000,
        sellingPrice: 12000,
        stock: 3,
        minimumStock: 5,
        unit: 'bungkus',
        isActive: true,
      ),
    ],
  };

  final Map<String, List<SalesTransaction>> _transactionsByBusiness = {
    'preview-business': [
      SalesTransaction(
        id: 'preview-transaction-3',
        invoiceNumber: 'INV-20260808-003',
        total: 48000,
        paymentMethod: 'CASH',
        createdAt: DateTime(2026, 8, 8, 10, 42),
        subtotal: 48000,
        amountPaid: 50000,
        changeAmount: 2000,
        paymentStatus: 'PAID',
        items: [
          TransactionLine(
            productName: 'Kopi Susu Gula Aren',
            quantity: 2,
            sellingPrice: 18000,
            subtotal: 36000,
          ),
          TransactionLine(
            productName: 'Keripik Pisang Cokelat',
            quantity: 1,
            sellingPrice: 12000,
            subtotal: 12000,
          ),
        ],
      ),
      SalesTransaction(
        id: 'preview-transaction-2',
        invoiceNumber: 'INV-20260808-002',
        total: 30000,
        paymentMethod: 'QRIS',
        createdAt: DateTime(2026, 8, 8, 9, 30),
        subtotal: 30000,
        amountPaid: 30000,
        paymentStatus: 'PAID',
        items: [
          TransactionLine(
            productName: 'Nasi Goreng Spesial',
            quantity: 1,
            sellingPrice: 30000,
            subtotal: 30000,
          ),
        ],
      ),
    ],
  };

  List<Category> get categories => categoriesFor(business.id);
  List<Product> get products => productsFor(business.id);
  List<SalesTransaction> get transactions => transactionsFor(business.id);

  List<Category> categoriesFor(String businessId) =>
      _categoriesByBusiness.putIfAbsent(businessId, () => []);

  List<Product> productsFor(String businessId) =>
      _productsByBusiness.putIfAbsent(businessId, () => []);

  List<SalesTransaction> transactionsFor(String businessId) =>
      _transactionsByBusiness.putIfAbsent(businessId, () => []);

  SalesTransaction transactionById(String transactionId) {
    for (final transactions in _transactionsByBusiness.values) {
      final index = transactions.indexWhere((item) => item.id == transactionId);
      if (index >= 0) return transactions[index];
    }
    throw StateError('Transaksi tidak ditemukan.');
  }
}

final developmentPreviewStoreProvider = Provider<DevelopmentPreviewStore>(
  (ref) => DevelopmentPreviewStore(),
);
