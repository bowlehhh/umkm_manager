import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_manager/features/entitlements/domain/access_route_resolver.dart';
import 'package:umkm_manager/features/entitlements/domain/entitlement.dart';

void main() {
  group('authenticated access route precedence', () {
    test('unauthenticated visitor is redirected to login', () {
      expect(
        AccessRouteResolver.unauthenticatedRedirect(isAuthRoute: false),
        '/login',
      );
      expect(
        AccessRouteResolver.unauthenticatedRedirect(isAuthRoute: true),
        isNull,
      );
    });

    test('admin without a subscription opens admin dashboard', () {
      expect(
        AccessRouteResolver.authenticatedHome(
          const Entitlement(isActive: false, role: 'admin'),
        ),
        '/admin',
      );
    });

    test('admin with expired subscription opens admin dashboard', () {
      expect(
        AccessRouteResolver.authenticatedHome(
          Entitlement(
            isActive: false,
            role: 'admin',
            expiresAt: DateTime(2020),
          ),
        ),
        '/admin',
      );
    });

    test('admin with active subscription opens admin dashboard', () {
      expect(
        AccessRouteResolver.authenticatedHome(
          const Entitlement(isActive: true, role: 'admin'),
        ),
        '/admin',
      );
    });

    test(
      'expired AI plan keeps business access; disabled account is blocked',
      () {
        expect(
          AccessRouteResolver.authenticatedHome(
            const Entitlement(isActive: false),
          ),
          '/businesses',
        );
        expect(
          AccessRouteResolver.authenticatedHome(
            const Entitlement(isActive: true, accessEnabled: false),
          ),
          '/activate-access',
        );
      },
    );

    test('active user opens normal business flow', () {
      expect(
        AccessRouteResolver.authenticatedHome(
          const Entitlement(isActive: true),
        ),
        '/businesses',
      );
    });
  });
}
