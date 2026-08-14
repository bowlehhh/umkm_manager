import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../businesses/data/business_repository.dart';
import '../../data/auth_repository.dart';

class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._repository, this._onAuthenticationChanged) {
    _isAuthenticated = _repository.hasVerifiedSession;
    _subscription = _repository.authStateChanges.listen((_) {
      final nextAuthenticated = _repository.hasVerifiedSession;
      if (nextAuthenticated != _isAuthenticated) {
        _isAuthenticated = nextAuthenticated;
        _onAuthenticationChanged();
      }
      notifyListeners();
    });
  }

  final AuthRepository _repository;
  final VoidCallback _onAuthenticationChanged;
  late final StreamSubscription<void> _subscription;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authStateNotifierProvider = Provider<AuthStateNotifier>((ref) {
  final notifier = AuthStateNotifier(
    ref.watch(authRepositoryProvider),
    () => ref.invalidate(businessSessionProvider),
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});
