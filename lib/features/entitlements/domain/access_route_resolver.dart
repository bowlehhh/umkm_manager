import 'entitlement.dart';

/// Resolves the first authenticated destination from the server-side access
/// decision. Keep this separate from the widget so the precedence is tested.
abstract final class AccessRouteResolver {
  static String? unauthenticatedRedirect({required bool isAuthRoute}) =>
      isAuthRoute ? null : '/login';

  static String authenticatedHome(Entitlement entitlement) {
    // An authenticated admin is never subject to the customer subscription
    // gate. The database RPC and every admin RPC remain the authority.
    if (entitlement.isAdmin) return '/admin';
    // Langganan hanya memberi kuota AI. Kedaluwarsa tidak boleh menyandera
    // produk, transaksi, laporan, atau data usaha yang sudah dimiliki.
    if (!entitlement.accessEnabled) {
      return '/activate-access';
    }
    return '/businesses';
  }
}
