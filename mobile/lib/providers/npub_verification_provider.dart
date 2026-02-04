// ABOUTME: Riverpod providers for npub verification redirect guards
// ABOUTME: Checks verification status for invite skip flow

import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/invite_code_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/npub_verification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'npub_verification_provider.g.dart';

/// Provider for NpubVerificationBloc instance.
///
/// This is created as a Riverpod provider so it can be accessed in both:
/// - The router (for AppStateListenable)
/// - The widget tree (via BlocProvider.value)
@Riverpod(keepAlive: true)
NpubVerificationBloc npubVerificationBloc(Ref ref) {
  final service = ref.watch(npubVerificationServiceProvider);
  final repository = ref.watch(npubVerificationRepositoryProvider);
  final bloc = NpubVerificationBloc(
    verificationService: service,
    repository: repository,
  );
  ref.onDispose(bloc.close);
  return bloc;
}

/// Provider for NpubVerificationRepository instance.
///
/// Lightweight provider for npub verification storage - safe for router redirects.
@Riverpod(keepAlive: true)
NpubVerificationRepository npubVerificationRepository(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NpubVerificationRepository(prefs);
}

/// Provider for NpubVerificationService instance.
///
/// Uses keepAlive to maintain singleton behavior across navigation.
/// Reuses device ID from InviteCodeService.
@Riverpod(keepAlive: true)
NpubVerificationService npubVerificationService(Ref ref) {
  final repository = ref.watch(npubVerificationRepositoryProvider);
  final inviteCodeService = ref.watch(inviteCodeServiceProvider);

  final service = NpubVerificationService(
    repository: repository,
    getDeviceId: inviteCodeService.getDeviceId,
  );

  ref.onDispose(service.dispose);
  return service;
}

/// Synchronous provider that checks if current user's npub is verified.
///
/// Returns true if:
/// - User has a valid invite code (skip verification entirely), OR
/// - User's npub has been verified with the server
///
/// Use this for router redirect logic.
@Riverpod(keepAlive: true)
bool isNpubVerified(Ref ref) {
  // Users with valid invite codes skip npub verification entirely
  final hasInviteCode = ref.watch(hasStoredInviteCodeProvider);
  if (hasInviteCode) {
    return true;
  }

  // Check verification status for current user's npub
  final authService = ref.watch(authServiceProvider);
  final npub = authService.currentNpub;

  if (npub == null) {
    // Not authenticated, so verification status is irrelevant
    return false;
  }

  final repository = ref.watch(npubVerificationRepositoryProvider);
  return repository.isVerified(npub);
}

/// Provider that checks if user needs npub verification.
///
/// Returns true if:
/// - User is authenticated AND
/// - User does NOT have an invite code AND
/// - User's npub is NOT yet verified
///
/// Use this in router redirect to gate access to home/explore.
@Riverpod(keepAlive: true)
bool needsNpubVerification(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final isAuthenticated = authService.authState == AuthState.authenticated;

  if (!isAuthenticated) {
    return false; // Not authenticated, no verification needed yet
  }

  // Users with invite codes don't need npub verification
  final hasInviteCode = ref.watch(hasStoredInviteCodeProvider);
  if (hasInviteCode) {
    return false;
  }

  // Check if already verified
  final isVerified = ref.watch(isNpubVerifiedProvider);
  return !isVerified;
}

// NOTE: SkipInviteRequested class has been removed.
// This is now handled by NpubVerificationBloc with events:
// - NpubVerificationSkipInviteSet (when user clicks "Sign In")
// - NpubVerificationSkipInviteCleared (after verification or failure)
