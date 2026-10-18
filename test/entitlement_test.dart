import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/entitlements/domain/entitlement.dart';

void main() {
  test('role admin berasal dari entitlement backend', () {
    const admin = Entitlement(isActive: true, role: 'admin');
    const user = Entitlement(isActive: true, role: 'user');

    expect(admin.isAdmin, isTrue);
    expect(user.isAdmin, isFalse);
  });

  test('akses disabled tetap dibedakan dari subscription aktif', () {
    const entitlement = Entitlement(isActive: true, accessEnabled: false);

    expect(entitlement.isActive, isTrue);
    expect(entitlement.accessEnabled, isFalse);
  });

  test(
    'entitlement aktif tetap membutuhkan keputusan backend, bukan fallback lokal',
    () {
      const entitlement = Entitlement(isActive: false, accessEnabled: true);

      expect(entitlement.isActive, isFalse);
    },
  );
}
