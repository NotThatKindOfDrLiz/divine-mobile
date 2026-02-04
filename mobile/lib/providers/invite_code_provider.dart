// ABOUTME: Riverpod providers for invite code verification state
// ABOUTME: Provides service instance and verification status for router redirects

import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'invite_code_provider.g.dart';

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
  final service = InviteCodeService(repository: repository, prefs: prefs);
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

/// State notifier for invite code entry/claiming.
///
/// Manages the async state of claiming an invite code.
/// Uses keepAlive to prevent disposal during async operations.
@Riverpod(keepAlive: true)
class InviteCodeClaim extends _$InviteCodeClaim {
  @override
  AsyncValue<InviteCodeResult?> build() {
    return const AsyncValue.data(null);
  }

  /// Claim an invite code.
  ///
  /// Updates state to loading, then data/error.
  /// On success, invalidates [hasStoredInviteCodeProvider] to trigger router refresh.
  Future<InviteCodeResult> claimCode(String code) async {
    state = const AsyncValue.loading();

    try {
      final service = ref.read(inviteCodeServiceProvider);
      final result = await service.claimCode(code);

      // Check if provider was disposed during async operation
      if (!ref.mounted) {
        return result;
      }

      state = AsyncValue.data(result);

      if (result.valid) {
        // Invalidate the hasStoredInviteCode provider to trigger router refresh
        ref.invalidate(hasStoredInviteCodeProvider);
      }

      return result;
    } catch (e, stack) {
      // Check if provider was disposed during async operation
      if (!ref.mounted) {
        rethrow;
      }
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Reset state to initial (no result).
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// Provider to store pending invite code from deep link.
///
/// When a deep link like https://divine.video/invite/ABC123 is received,
/// the code is stored here so the InviteCodeEntryScreen can auto-fill it.
@riverpod
class PendingInviteCode extends _$PendingInviteCode {
  @override
  String? build() => null;

  /// Set a pending invite code from deep link.
  void setCode(String code) {
    state = code.toUpperCase().trim();
  }

  /// Clear the pending code after it's been processed.
  void clear() {
    state = null;
  }
}
