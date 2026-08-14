import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/businesses/data/business_repository.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';

void main() {
  test('business session menyimpan banyak membership dan usaha aktif', () {
    const toko = Business(
      id: 'toko',
      name: 'Toko Sparepart',
      type: BusinessType.retail,
      role: BusinessMemberRole.owner,
    );
    const studio = Business(
      id: 'studio',
      name: 'Cahaya Fotografi',
      type: BusinessType.service,
      role: BusinessMemberRole.admin,
      isActive: true,
    );

    final session = BusinessSession([toko, studio]);

    expect(session.hasBusinesses, isTrue);
    expect(session.businesses, hasLength(2));
    expect(session.activeBusiness?.id, 'studio');
    expect(session.activeBusiness?.role, BusinessMemberRole.admin);
  });

  test('role membership dibaca per usaha', () {
    expect(BusinessMemberRole.fromDatabase('OWNER').label, 'Owner');
    expect(BusinessMemberRole.fromDatabase('ADMIN').label, 'Admin');
    expect(BusinessMemberRole.fromDatabase('CASHIER').label, 'Kasir');
  });
}
