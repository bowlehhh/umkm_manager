import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_state_notifier.dart';
import '../../features/auth/presentation/views/forgot_password_page.dart';
import '../../features/auth/presentation/views/login_page.dart';
import '../../features/auth/presentation/views/register_page.dart';
import '../../features/biometrics/presentation/controllers/biometric_session_notifier.dart';
import '../../features/biometrics/presentation/views/biometric_lock_page.dart';
import '../../features/businesses/presentation/views/business_gate.dart';
import '../../features/businesses/presentation/views/business_selector_page.dart';
import '../../features/ai_business_builder/presentation/views/ai_business_setup_page.dart';
import '../../features/development_preview/presentation/views/preview_feature_page.dart';
import '../../features/settings/presentation/views/security_page.dart';
import '../../features/settings/presentation/views/settings_page.dart';
import '../../features/transactions/presentation/views/transaction_detail_page.dart';
import '../../features/customers/presentation/views/customer_detail_page.dart';
import '../../features/customers/presentation/views/customer_form_page.dart';
import '../../shared/widgets/configuration_required_page.dart';
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
    redirect: (context, state) {
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
      if (!isAuthenticated) return isAuthRoute ? null : '/login';
      final biometricState = biometricNotifier!.state;
      if (biometricState.isLoading || biometricState.requiresUnlock) {
        return location == '/biometric-lock' ? null : '/biometric-lock';
      }
      if (location == '/biometric-lock') return '/businesses';
      return isAuthRoute || location == '/splash' ? '/businesses' : null;
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
          previewFeature: PreviewFeature.expenses,
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
        builder: (context, state) => const BusinessGate(
          currentRoute: '/reports',
          featureKey: 'reports',
          previewFeature: PreviewFeature.reports,
        ),
      ),
      GoRoute(
        path: '/stock',
        builder: (context, state) =>
            const BusinessGate(currentRoute: '/stock', featureKey: 'stock'),
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
          childBuilder: (_, _) => const SettingsPage(),
        ),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => BusinessGate(
          currentRoute: '/settings',
          childBuilder: (_, _) => const SecurityPage(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri.path}')),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
