// ABOUTME: BLoC for waitlist email signup
// ABOUTME: Manages waitlist submission state

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'waitlist_event.dart';
part 'waitlist_state.dart';

/// BLoC for managing waitlist email signup.
///
/// Handles:
/// - Submitting email addresses to the waitlist
/// - Tracking submission state for UI updates
class WaitlistBloc extends Bloc<WaitlistEvent, WaitlistState> {
  WaitlistBloc() : super(const WaitlistState()) {
    on<WaitlistEmailSubmitted>(_onEmailSubmitted);
    on<WaitlistReset>(_onReset);
  }

  Future<void> _onEmailSubmitted(
    WaitlistEmailSubmitted event,
    Emitter<WaitlistState> emit,
  ) async {
    emit(state.copyWith(status: WaitlistStatus.submitting, clearError: true));

    try {
      // TODO: Implement actual waitlist API call
      // For now, simulate API call with delay
      await Future<void>.delayed(const Duration(seconds: 1));

      Log.info(
        'Email added to waitlist: ${event.email}',
        name: 'WaitlistBloc',
        category: LogCategory.auth,
      );

      emit(
        state.copyWith(
          status: WaitlistStatus.success,
          submittedEmail: event.email,
        ),
      );
    } catch (e) {
      Log.error(
        'Failed to add email to waitlist: $e',
        name: 'WaitlistBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          status: WaitlistStatus.failure,
          error: 'Failed to join waitlist. Please try again.',
        ),
      );
    }
  }

  void _onReset(WaitlistReset event, Emitter<WaitlistState> emit) {
    emit(const WaitlistState());
  }
}
