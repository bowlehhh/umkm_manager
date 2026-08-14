class Business {
  const Business({
    required this.id,
    required this.name,
    required this.type,
    this.address,
    this.phone,
    this.role = BusinessMemberRole.owner,
    this.isActive = false,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as String,
      name: json['name'] as String,
      type: BusinessType.fromDatabase(json['business_type'] as String?),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      role: BusinessMemberRole.fromDatabase(json['role'] as String?),
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final BusinessType type;
  final String? address;
  final String? phone;
  final BusinessMemberRole role;
  final bool isActive;
}

enum BusinessMemberRole {
  owner('OWNER', 'Owner'),
  admin('ADMIN', 'Admin'),
  cashier('CASHIER', 'Kasir');

  const BusinessMemberRole(this.databaseValue, this.label);

  factory BusinessMemberRole.fromDatabase(String? value) =>
      BusinessMemberRole.values.firstWhere(
        (role) => role.databaseValue == value,
        orElse: () => BusinessMemberRole.cashier,
      );

  final String databaseValue;
  final String label;
}

enum BusinessType {
  retail('RETAIL', 'Toko / Retail', 'Produk'),
  culinary('CULINARY', 'Makanan & Minuman', 'Menu'),
  service('SERVICE', 'Jasa / Layanan', 'Layanan'),
  fashion('FASHION', 'Fashion', 'Produk'),
  other('OTHER', 'Usaha lainnya', 'Produk');

  const BusinessType(this.databaseValue, this.label, this.itemLabel);

  factory BusinessType.fromDatabase(String? value) =>
      BusinessType.values.firstWhere(
        (type) => type.databaseValue == value,
        orElse: () => BusinessType.retail,
      );

  final String databaseValue;
  final String label;
  final String itemLabel;

  /// Layanan tidak memiliki persediaan fisik, jadi stok tidak ditampilkan
  /// atau dikurangi pada saat transaksi.
  bool get usesInventory => this != BusinessType.service;
}
