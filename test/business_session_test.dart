import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/businesses/data/business_repository.dart';
import 'package:umkm_manager/features/businesses/data/supabase_business_repository.dart';
import 'package:umkm_manager/features/businesses/domain/business.dart';
import 'package:umkm_manager/features/businesses/presentation/views/business_selector_page.dart';

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

  test('membership akun yang sudah ada selalu membentuk daftar usaha', () {
    final businesses = mapBusinessMemberships(
      const [
        {'business_id': 'warung-maju', 'role': 'OWNER', 'is_active': true},
        {'business_id': 'toko-samping', 'role': 'ADMIN', 'is_active': false},
      ],
      const [
        {
          'id': 'warung-maju',
          'name': 'Warung Maju',
          'business_type': 'CULINARY',
        },
        {
          'id': 'toko-samping',
          'name': 'Toko Samping',
          'business_type': 'RETAIL',
        },
      ],
    );

    final session = BusinessSession(businesses);

    expect(session.hasBusinesses, isTrue);
    expect(session.businesses, hasLength(2));
    expect(session.activeBusiness?.id, 'warung-maju');
  });

  test('akses aktif tanpa usaha diarahkan untuk membuat usaha', () {
    expect(
      resolveBusinessFlowDestination(const BusinessSession([])),
      '/businesses/new',
    );
  });

  test('akses aktif dengan usaha terpilih diarahkan ke dashboard', () {
    const business = Business(
      id: 'toko',
      name: 'Toko Maju',
      type: BusinessType.retail,
      role: BusinessMemberRole.owner,
      isActive: true,
    );

    expect(
      resolveBusinessFlowDestination(const BusinessSession([business])),
      '/dashboard',
    );
  });
}
