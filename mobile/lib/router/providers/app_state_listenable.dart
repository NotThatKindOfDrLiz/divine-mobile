// ABOUTME: Listenable that notifies when auth, invite code, or verification state changes
// ABOUTME: Used by GoRouter's refreshListenable to trigger route redirects

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/blocs/invite_code/invite_code_bloc.dart';
import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/services/auth_service.dart';

/// Listenable that notifies router when auth, invite code,
/// or verification state changes.
///
/// This is a composite listenable that listens to:
/// - Auth state changes (login/logout)
/// - Invite code state changes (code claimed)
/// - Npub verification state changes (verified, skip flag set/cleared)
///
/// The router uses this to trigger redirect re-evaluation when any of
/// these states change.
class AppStateListenable extends ChangeNotifier {
  AppStateListenable({
    required AuthService authService,
    required InviteCodeBloc inviteCodeBloc,
    required NpubVerificationBloc npubVerificationBloc,
  })  : _authService = authService,
        _inviteCodeBloc = inviteCodeBloc,
        _npubVerificationBloc = npubVerificationBloc {
    _lastAuthState = _authService.authState;

    _authSubscription = _authService.authStateStream.listen((newState) {
      // Only notify when transitioning to or from authenticated state
      final wasAuthenticated = _lastAuthState == AuthState.authenticated;
      final isAuthenticated = newState == AuthState.authenticated;

      _lastAuthState = newState;

      if (wasAuthenticated != isAuthenticated) {
        notifyListeners();
      }
    });

    _inviteCodeSubscription = _inviteCodeBloc.stream.listen((state) {
      // Notify when invite code status changes to success (code claimed)
      if (state.status == InviteCodeStatus.success) {
        notifyListeners();
      }
    });

    _verificationSubscription = _npubVerificationBloc.stream.listen((state) {
      // Notify on any verification state change
      // (verified, failed, skip flag changed)
      notifyListeners();
    });
  }

  final AuthService _authService;
  final InviteCodeBloc _inviteCodeBloc;
  final NpubVerificationBloc _npubVerificationBloc;

  AuthState? _lastAuthState;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<InviteCodeState>? _inviteCodeSubscription;
  StreamSubscription<NpubVerificationState>? _verificationSubscription;

  // Synchronous getters for router redirect logic

  /// Whether the device has a verified invite code stored locally.
  bool get hasInviteCode => _inviteCodeBloc.hasStoredInviteCode;

  /// Whether user has requested to skip invite code entry.
  bool get skipInviteRequested => _npubVerificationBloc.skipInviteRequested;

  /// Check if the given npub is verified.
  bool isNpubVerified(String? npub) => _npubVerificationBloc.isNpubVerified(npub);

  @override
  void dispose() {
    _authSubscription?.cancel();
    _inviteCodeSubscription?.cancel();
    _verificationSubscription?.cancel();
    super.dispose();
  }
}
