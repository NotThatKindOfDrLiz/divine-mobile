// ABOUTME: BLoC for npub verification during invite skip flow
// ABOUTME: Manages verification state with synchronous getters for router

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/services/npub_verification_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'npub_verification_event.dart';
part 'npub_verification_state.dart';

/// BLoC for managing npub verification operations.
///
/// Used when users skip invite code by signing in with existing account.
/// Server verifies the npub is authorized for access.
///
/// Handles:
/// - Verifying npubs with the server
/// - Managing skip invite flag (in-memory only)
/// - Providing synchronous state for router redirect logic
class NpubVerificationBloc
    extends Bloc<NpubVerificationEvent, NpubVerificationState> {
  NpubVerificationBloc({
    required NpubVerificationService verificationService,
    required NpubVerificationRepository repository,
  }) : _service = verificationService,
       _repository = repository,
       super(const NpubVerificationState()) {
    on<NpubVerificationRequested>(_onVerificationRequested);
    on<NpubVerificationSkipInviteSet>(_onSkipInviteSet);
    on<NpubVerificationSkipInviteCleared>(_onSkipInviteCleared);
    on<NpubVerificationReset>(_onReset);
  }

  final NpubVerificationService _service;
  final NpubVerificationRepository _repository;

  /// Synchronous check if npub is verified (for router).
  ///
  /// Returns true if the given npub has been verified with the server.
  bool isNpubVerified(String? npub) {
    if (npub == null) return false;
    return _repository.isVerified(npub);
  }

  /// Synchronous getter for skip invite flag (for router).
  ///
  /// Returns true if user has requested to skip invite code entry
  /// by clicking "Sign In" on the invite screen.
  bool get skipInviteRequested => state.skipInviteRequested;

  Future<void> _onVerificationRequested(
    NpubVerificationRequested event,
    Emitter<NpubVerificationState> emit,
  ) async {
    emit(
      state.copyWith(
        status: NpubVerificationStatus.verifying,
        clearError: true,
      ),
    );

    try {
      final result = await _service.verifyNpub(event.npub);

      if (result.valid) {
        Log.info(
          'Npub verified successfully',
          name: 'NpubVerificationBloc',
          category: LogCategory.auth,
        );
        emit(
          state.copyWith(
            status: NpubVerificationStatus.verified,
            skipInviteRequested: false, // Clear on success
          ),
        );
      } else {
        Log.warning(
          'Npub verification rejected: ${result.message}',
          name: 'NpubVerificationBloc',
          category: LogCategory.auth,
        );
        emit(
          state.copyWith(
            status: NpubVerificationStatus.rejected,
            error: result.message,
          ),
        );
      }
    } on NpubVerificationException catch (e) {
      Log.error(
        'Npub verification exception: ${e.message}',
        name: 'NpubVerificationBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(status: NpubVerificationStatus.failed, error: e.message),
      );
    } catch (e) {
      Log.error(
        'Npub verification failed: $e',
        name: 'NpubVerificationBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          status: NpubVerificationStatus.failed,
          error: 'Verification failed. Please try again.',
        ),
      );
    }
  }

  void _onSkipInviteSet(
    NpubVerificationSkipInviteSet event,
    Emitter<NpubVerificationState> emit,
  ) {
    Log.info(
      'Skip invite flag set',
      name: 'NpubVerificationBloc',
      category: LogCategory.auth,
    );
    emit(state.copyWith(skipInviteRequested: true));
  }

  void _onSkipInviteCleared(
    NpubVerificationSkipInviteCleared event,
    Emitter<NpubVerificationState> emit,
  ) {
    Log.info(
      'Skip invite flag cleared',
      name: 'NpubVerificationBloc',
      category: LogCategory.auth,
    );
    emit(state.copyWith(skipInviteRequested: false));
  }

  void _onReset(
    NpubVerificationReset event,
    Emitter<NpubVerificationState> emit,
  ) {
    emit(const NpubVerificationState());
  }
}
