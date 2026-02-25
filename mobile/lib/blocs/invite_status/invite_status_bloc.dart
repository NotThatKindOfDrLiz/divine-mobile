// ABOUTME: BLoC for invite status screen
// ABOUTME: Fetches authenticated user's invite status via NIP-98 auth

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/services/invite_code_service.dart';

part 'invite_status_event.dart';
part 'invite_status_state.dart';

/// BLoC for managing invite status fetching.
///
/// Handles:
/// - Fetching the authenticated user's invite status via NIP-98 auth
/// - Retry on failure
class InviteStatusBloc extends Bloc<InviteStatusEvent, InviteStatusState> {
  InviteStatusBloc({required InviteCodeService inviteCodeService})
    : _service = inviteCodeService,
      super(const InviteStatusState()) {
    on<InviteStatusRequested>(_onRequested, transformer: droppable());
  }

  final InviteCodeService _service;

  Future<void> _onRequested(
    InviteStatusRequested event,
    Emitter<InviteStatusState> emit,
  ) async {
    emit(state.copyWith(status: InviteStatusStatus.loading, clearError: true));

    try {
      final result = await _service.getInviteStatus();
      emit(state.copyWith(status: InviteStatusStatus.success, result: result));
    } on InviteCodeException catch (e) {
      emit(
        state.copyWith(status: InviteStatusStatus.failure, error: e.message),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: InviteStatusStatus.failure,
          error: 'Failed to load invite status',
        ),
      );
    }
  }
}
