import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_state_notifier.dart';
import '../../features/auth/presentation/views/forgot_password_page.dart';
import '../../features/auth/presentation/views/login_page.dart';
import '../../features/auth/presentation/views/register_page.dart';
import '../../features/auth/presentation/views/reset_password_page.dart';
import '../../features/admin/presentation/views/admin_dashboard_page.dart';
import '../../features/biometrics/presentation/controllers/biometric_session_notifier.dart';
import '../../features/biometrics/presentation/views/biometric_lock_page.dart';
import '../../features/businesses/presentation/views/business_gate.dart';
import '../../features/businesses/presentation/views/business_selector_page.dart';
import '../../features/business_configuration/presentation/views/business_feature_settings_page.dart';
import '../../features/ai_business_builder/presentation/views/ai_business_setup_page.dart';
import '../../features/development_preview/presentation/views/preview_feature_page.dart';
import '../../features/settings/presentation/views/security_page.dart';
import '../../features/settings/presentation/views/settings_page.dart';
import '../../features/subscriptions/presentation/subscription_page.dart';
import '../../features/entitlements/presentation/views/account_flow_page.dart';
import '../../features/entitlements/presentation/views/access_expired_page.dart';
import '../../features/entitlements/domain/access_route_resolver.dart';
import '../../features/entitlements/data/entitlement_service.dart';
import '../../features/transactions/presentation/views/transaction_detail_page.dart';
import '../../features/customers/presentation/views/customer_detail_page.dart';
import '../../features/customers/presentation/views/customer_form_page.dart';
import '../../shared/widgets/configuration_required_page.dart';
import '../../shared/widgets/main_navigation_scaffold.dart';
import '../../shared/widgets/splash_page.dart';
import '../config/app_config.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);
  final authNotifier = config.isSupabaseConfigured
      ? ref.watch(authStateNotifierProvider)
      : null;
  final biometricNotifier = config.isSupabaseConfigured
      ? ref.watch(biometricSessionNotifierProvider)
      : null;

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: config.isSupabaseConfigured
        ? Listenable.merge([authNotifier!, biometricNotifier!])
        : null,
    redirect: (context, state) async {
      final location = state.matchedLocation;
      if (!config.isSupabaseConfigured) {
        return location == '/configuration-required'
            ? null
            : '/configuration-required';
      }

      final isAuthRoute = switch (location) {
        '/login' || '/register' || '/forgot-password' => true,
        _ => false,
      };
      final isAuthenticated = authNotifier!.isAuthenticated;
      if (!isAuthenticated) {
        return AccessRouteResolver.unauthenticatedRedirect(
          isAuthRoute: isAuthRoute,
        );
      }
      final biometricState = biometricNotifier!.state;
      // Pemeriksaan ketersediaan biometrik berjalan di latar belakang. Jangan
      // jadikan proses itu layar penghalang bagi pengguna baru yang belum
      // pernah mengaktifkan biometrik.
      if (biometricState.requiresUnlock) {
        return location == '/biometric-lock' ? null : '/biometric-lock';
      }
      if (location == '/biometric-lock') return '/account';
      // Supabase opens this route after an email-recovery deep link. It must
      // remain reachable for the authenticated recovery session.
      if (location == '/reset-password') return null;
      if (isAuthRoute || location == '/splash') return '/account';
      // AccountFlow owns the initial loading state. Every other protected
      // location is guarded here as well, so an unentitled user cannot reach
      // a business route simply by typing its URL.
      if (location == '/account') return null;
      try {
        final entitlement = await ref
            .read(entitlementServiceProvider)
            .getCurrentEntitlement();
        final destination = AccessRouteResolver.authenticatedHome(entitlement);
        if (destination == '/admin') {
          return location == '/admin' ? null : '/admin';
        }
        if (destination == '/activate-access') {
          return location == '/activate-access' ? null : '/activate-access';
        }
        // A regular user with active server-side entitlement can use only the
        // user application, never an admin URL.
        return location == '/admin' ? '/businesses' : null;
      } catch (_) {
        // Fail closed: do not let an unknown entitlement result open a
        // business page through a deep link or navigation history. AccountFlow
        // provides the retry UI for the same server-side access decision.
        return '/account';
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/configuration-required',
        builder: (context, state) => const ConfigurationRequiredPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountFlowPage(),
      ),
      GoRoute(
        path: '/activate-access',
        builder: (context, state) => const AccessExpiredPage(),
      ),
      GoRoute(path: '/access-expired', redirect: (_, _) => '/activate-access'),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminGatePage(),
      ),
      GoRoute(
        path: '/biometric-lock',
        builder: (context, state) => const BiometricLockPage(),
      ),
      GoRoute(
        path: '/businesses',
        builder: (context, state) => const BusinessFlowPage(),
      ),
      GoRoute(
        path: '/businesses/select',
        builder: (context, state) => const BusinessSelectorPage(),
      ),
      GoRoute(
        path: '/businesses/new',
        builder: (context, state) => const AiBusinessSetupPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) =>
            const BusinessGate(currentRoute: '/dashboard'),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/transactions',
          featureKey: 'transactions',
        ),
      ),
      GoRoute(
        path: '/transactions/:transactionId',
        builder: (context, state) => BusinessGate(
          currentRoute: '/transactions',
          featureKey: 'transactions',
          childBuilder: (business, _) => TransactionDetailPage(
            businessId: business.id,
            transactionId: state.pathParameters['transactionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/cashier',
        builder: (context, state) =>
            const BusinessGate(currentRoute: '/cashier', featureKey: 'cashier'),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/products',
          featureKey: 'products',
        ),
      ),
      GoRoute(
        path: '/more',
        builder: (context, state) => const BusinessGate(currentRoute: '/more'),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/customers',
          featureKey: 'customers',
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => BusinessGate(
              currentRoute: '/customers',
              featureKey: 'customers',
              childBuilder: (business, _) =>
                  CustomerFormPage(businessId: business.id),
            ),
          ),
          GoRoute(
            path: ':customerId',
            builder: (context, state) => BusinessGate(
              currentRoute: '/customers',
              featureKey: 'customers',
              childBuilder: (business, configuration) => CustomerDetailPage(
                businessId: business.id,
                customerId: state.pathParameters['customerId']!,
                showDebt: configuration.features.any(
                  (item) => item.key == 'debts' && item.enabled,
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => BusinessGate(
                  currentRoute: '/customers',
                  featureKey: 'customers',
                  childBuilder: (business, _) => CustomerEditPage(
                    businessId: business.id,
                    customerId: state.pathParameters['customerId']!,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/debts',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/debts',
          featureKey: 'debts',
          previewFeature: PreviewFeature.debts,
        ),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/expenses',
          featureKey: 'expenses',
        ),
      ),
      GoRoute(
        path: '/discounts',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/discounts',
          featureKey: 'discounts',
          previewFeature: PreviewFeature.discounts,
        ),
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/employees',
          featureKey: 'employees',
          previewFeature: PreviewFeature.employees,
        ),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) =>
            const BusinessGate(currentRoute: '/reports', featureKey: 'reports'),
      ),
      GoRoute(
        path: '/stock',
        builder: (context, state) =>
            const BusinessGate(currentRoute: '/stock', featureKey: 'stock'),
      ),
      GoRoute(
        path: '/custom-records',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/custom-records',
          featureKey: 'custom_records',
        ),
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) =>
            const BusinessGate(currentRoute: '/booking', featureKey: 'booking'),
      ),
      GoRoute(
        path: '/appointments',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/appointments',
          featureKey: 'appointments',
        ),
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/services',
          featureKey: 'services',
        ),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/projects',
          featureKey: 'projects',
        ),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) =>
            const BusinessGate(currentRoute: '/orders', featureKey: 'orders'),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const BusinessGate(
          currentRoute: '/payments',
          featureKey: 'payments',
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => BusinessGate(
          currentRoute: '/settings',
          childBuilder: (business, configuration) => MainNavigationScaffold(
            business: business,
            configuration: configuration,
            currentRoute: '/more',
            content: SettingsPage(
              businessId: business.id,
              configuration: configuration,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/features',
        builder: (context, state) => BusinessGate(
          currentRoute: '/settings',
          childBuilder: (business, configuration) => MainNavigationScaffold(
            business: business,
            configuration: configuration,
            currentRoute: '/more',
            content: BusinessFeatureSettingsPage(
              business: business,
              initialConfiguration: configuration,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => BusinessGate(
          currentRoute: '/settings',
          childBuilder: (business, configuration) => MainNavigationScaffold(
            business: business,
            configuration: configuration,
            currentRoute: '/more',
            content: const SecurityPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri.path}')),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
