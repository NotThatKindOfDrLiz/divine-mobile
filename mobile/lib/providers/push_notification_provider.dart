// ABOUTME: Riverpod provider for FCM push notification lifecycle management
// ABOUTME: Auto-registers on login, deregisters on logout, re-registers on
// token refresh

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'push_notification_provider.g.dart';

/// State for the push notification provider.
@immutable
class PushNotificationState {
  const PushNotificationState({
    this.isRegistered = false,
    this.isInitializing = false,
    this.error,
  });

  final bool isRegistered;
  final bool isInitializing;
  final String? error;

  PushNotificationState copyWith({
    bool? isRegistered,
    bool? isInitializing,
    String? error,
  }) {
    return PushNotificationState(
      isRegistered: isRegistered ?? this.isRegistered,
      isInitializing: isInitializing ?? this.isInitializing,
      error: error,
    );
  }

  static const initial = PushNotificationState();
}

/// Provider managing push notification registration lifecycle.
///
/// Watches auth state to automatically:
/// - Register FCM token on login
/// - Deregister on logout
/// - Re-register on token refresh
///
/// Skips initialization on web platform where FCM is not supported.
@Riverpod(keepAlive: true)
class PushNotifications extends _$PushNotifications {
  PushNotificationService? _service;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  PushNotificationState build() {
    final authService = ref.watch(authServiceProvider);

    // Clean up previous subscriptions
    _authSubscription?.cancel();

    // Listen for auth state changes to register/deregister
    _authSubscription = authService.authStateStream.listen(_onAuthStateChanged);

    ref.onDispose(() {
      _authSubscription?.cancel();
      _service?.dispose();
    });

    // If already authenticated, initialize immediately
    if (authService.isAuthenticated && !kIsWeb) {
      Future.microtask(_initializePush);
    }

    return PushNotificationState.initial;
  }

  Future<void> _onAuthStateChanged(AuthState newState) async {
    if (kIsWeb) return;

    switch (newState) {
      case AuthState.authenticated:
        await _initializePush();
        return;
      case AuthState.unauthenticated:
        await _deregister();
        return;
      case AuthState.checking:
      case AuthState.authenticating:
      case AuthState.awaitingTosAcceptance:
        break;
    }
  }

  /// Explicitly deregister before signing out while signer context is still
  /// available.
  Future<void> deregisterBeforeSignOut() async {
    if (kIsWeb) return;
    await _deregister();
  }

  Future<void> _initializePush() async {
    if (state.isInitializing || state.isRegistered) return;

    state = state.copyWith(isInitializing: true, error: null);

    try {
      final authService = ref.read(authServiceProvider);
      final nostrClient = ref.read(nostrServiceProvider);

      _service?.dispose();
      _service = PushNotificationService(
        authService: authService,
        nostrClient: nostrClient,
      );

      await _service!.initialize();

      state = state.copyWith(
        isRegistered: _service!.isRegistered,
        isInitializing: false,
      );

      Log.info(
        'Push notifications registered: ${_service!.isRegistered}',
        name: 'PushNotificationProvider',
        category: LogCategory.system,
      );
    } on Exception catch (e) {
      state = state.copyWith(isInitializing: false, error: e.toString());

      Log.error(
        'Failed to initialize push notifications: $e',
        name: 'PushNotificationProvider',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _deregister() async {
    try {
      await _service?.deregister();
      _service?.dispose();
      _service = null;

      state = PushNotificationState.initial;

      Log.info(
        'Push notifications deregistered',
        name: 'PushNotificationProvider',
        category: LogCategory.system,
      );
    } on Exception catch (e) {
      Log.error(
        'Failed to deregister push notifications: $e',
        name: 'PushNotificationProvider',
        category: LogCategory.system,
      );
    }
  }
}
