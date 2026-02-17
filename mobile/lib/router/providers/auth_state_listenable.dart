// ABOUTME: Listenable that notifies when auth state changes to/from authenticated
// ABOUTME: Used by GoRouter's refreshListenable to trigger route redirects

import 'package:flutter/foundation.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Listenable that notifies when auth state changes to/from authenticated.
///
/// Only notifies on meaningful state changes to avoid unnecessary router
/// refreshes during init/login flow.
class AuthStateListenable extends ChangeNotifier {
  AuthStateListenable(this._authService) {
    _lastState = _authService.authState;
    _authService.authStateStream.listen((newState) {
      // Only notify when transitioning to or from authenticated state
      // This prevents unnecessary router refreshes during init/login flow
      final wasAuthenticated = _lastState == AuthState.authenticated;
      final isAuthenticated = newState == AuthState.authenticated;

      if (wasAuthenticated != isAuthenticated) {
        Log.info(
          'AuthStateListenable: router redirect triggered — '
          '${_lastState?.name} -> ${newState.name}',
          name: 'AuthStateListenable',
          category: LogCategory.auth,
        );
        _lastState = newState;
        notifyListeners();
      } else {
        Log.debug(
          'AuthStateListenable: state changed '
          '${_lastState?.name} -> ${newState.name} '
          '(no router refresh — same auth boundary)',
          name: 'AuthStateListenable',
          category: LogCategory.auth,
        );
        _lastState = newState;
      }
    });
  }

  final AuthService _authService;
  AuthState? _lastState;
}
