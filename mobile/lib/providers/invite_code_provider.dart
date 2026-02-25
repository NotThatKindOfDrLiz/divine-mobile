// ABOUTME: Riverpod providers for invite code verification state
// ABOUTME: Provides service instance and verification status for router redirects

import 'package:openvine/blocs/invite_code/invite_code_bloc.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'invite_code_provider.g.dart';

/// Provider for InviteCodeBloc instance.
///
/// This is created as a Riverpod provider so it can be accessed in both:
/// - The router (for AppStateListenable)
/// - The widget tree (via BlocProvider.value)
@Riverpod(keepAlive: true)
InviteCodeBloc inviteCodeBloc(Ref ref) {
  final service = ref.watch(inviteCodeServiceProvider);
  final repository = ref.watch(inviteCodeRepositoryProvider);
  final bloc = InviteCodeBloc(
    inviteCodeService: service,
    repository: repository,
  );
  ref.onDispose(bloc.close);
  return bloc;
}

/// Provider for InviteCodeRepository instance.
///
/// Lightweight provider for invite code storage - safe for router redirects.
@Riverpod(keepAlive: true)
InviteCodeRepository inviteCodeRepository(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return InviteCodeRepository(prefs);
}

/// Provider for InviteCodeService instance.
///
/// Uses keepAlive to maintain singleton behavior across navigation.
@Riverpod(keepAlive: true)
InviteCodeService inviteCodeService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repository = ref.watch(inviteCodeRepositoryProvider);
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  final service = InviteCodeService(
    repository: repository,
    prefs: prefs,
    nip98AuthService: nip98AuthService,
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Synchronous check if an invite code is stored locally.
///
/// Use this for router redirect logic - it does NOT verify with server.
/// For full verification, use [inviteCodeVerificationProvider].
@Riverpod(keepAlive: true)
bool hasStoredInviteCode(Ref ref) {
  final service = ref.watch(inviteCodeServiceProvider);
  return service.hasVerifiedCode;
}

/// Async verification of stored invite code with server.
///
/// Returns InviteCodeResult with validity status.
/// Use [hasStoredInviteCodeProvider] for synchronous checks in redirects.
@riverpod
Future<InviteCodeResult> inviteCodeVerification(Ref ref) async {
  final service = ref.watch(inviteCodeServiceProvider);

  if (!service.hasVerifiedCode) {
    return const InviteCodeResult(
      valid: false,
      message: 'No invite code stored',
    );
  }

  return service.verifyStoredCode();
}

// NOTE: InviteCodeClaim class has been removed.
// This is now handled by InviteCodeBloc with the InviteCodeClaimRequested event.
