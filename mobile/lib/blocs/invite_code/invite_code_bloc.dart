// ABOUTME: BLoC for invite code claiming
// ABOUTME: Manages invite code state with synchronous getters for router

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'invite_code_event.dart';
part 'invite_code_state.dart';

/// BLoC for managing invite code operations.
///
/// Handles:
/// - Claiming invite codes via API
/// - Providing synchronous state for router redirect logic
class InviteCodeBloc extends Bloc<InviteCodeEvent, InviteCodeState> {
  InviteCodeBloc({
    required InviteCodeService inviteCodeService,
    required InviteCodeRepository repository,
  }) : _service = inviteCodeService,
       _repository = repository,
       super(InviteCodeState(hasStoredCode: repository.hasStoredCode)) {
    on<InviteCodeClaimRequested>(_onClaimRequested, transformer: droppable());
    on<InviteCodeReset>(_onReset);
  }

  final InviteCodeService _service;
  final InviteCodeRepository _repository;

  /// Synchronous getter for router redirect logic.
  ///
  /// Returns true if device has a verified invite code stored locally.
  bool get hasStoredInviteCode => _repository.hasStoredCode;

  Future<void> _onClaimRequested(
    InviteCodeClaimRequested event,
    Emitter<InviteCodeState> emit,
  ) async {
    emit(state.copyWith(status: InviteCodeStatus.loading, clearError: true));

    try {
      final result = await _service.claimCode(event.code);

      if (result.valid) {
        Log.info(
          'Invite code claimed successfully',
          name: 'InviteCodeBloc',
          category: LogCategory.auth,
        );
        emit(
          state.copyWith(
            status: InviteCodeStatus.success,
            hasStoredCode: true,
            result: result,
          ),
        );
      } else {
        Log.warning(
          'Invite code claim rejected: ${result.message}',
          name: 'InviteCodeBloc',
          category: LogCategory.auth,
        );
        emit(
          state.copyWith(
            status: InviteCodeStatus.failure,
            result: result,
            error: result.message,
          ),
        );
      }
    } on InviteCodeException catch (e) {
      Log.error(
        'Invite code exception: ${e.message}',
        name: 'InviteCodeBloc',
        category: LogCategory.auth,
      );
      emit(state.copyWith(status: InviteCodeStatus.failure, error: e.message));
    } catch (e) {
      Log.error(
        'Failed to claim invite code: $e',
        name: 'InviteCodeBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          status: InviteCodeStatus.failure,
          error: 'An unexpected error occurred. Please try again.',
        ),
      );
    }
  }

  void _onReset(InviteCodeReset event, Emitter<InviteCodeState> emit) {
    emit(InviteCodeState(hasStoredCode: _repository.hasStoredCode));
  }
}
