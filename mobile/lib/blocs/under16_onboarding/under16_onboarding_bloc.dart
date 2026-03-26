// ABOUTME: BLoC for the under-16 PRR-informed onboarding flow
// ABOUTME: Manages multi-step flow state from honesty screen through
// ABOUTME: parental consent to account creation readiness

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:openvine/blocs/under16_onboarding/under16_onboarding_event.dart';
import 'package:openvine/blocs/under16_onboarding/under16_onboarding_state.dart';

class Under16OnboardingBloc
    extends Bloc<Under16OnboardingEvent, Under16OnboardingState> {
  Under16OnboardingBloc() : super(const Under16OnboardingState()) {
    on<Under16OnboardingStarted>(_onStarted);
    on<Under16OnboardingOptionSelected>(_onOptionSelected);
    on<Under16OnboardingVideoRecorded>(
      _onVideoRecorded,
      transformer: droppable(),
    );
    on<Under16OnboardingVideoRetakeRequested>(_onVideoRetakeRequested);
    on<Under16OnboardingParentEmailEntered>(_onParentEmailEntered);
    on<Under16OnboardingCompleted>(
      _onCompleted,
      transformer: droppable(),
    );
  }

  void _onStarted(
    Under16OnboardingStarted event,
    Emitter<Under16OnboardingState> emit,
  ) {
    emit(const Under16OnboardingState());
  }

  void _onOptionSelected(
    Under16OnboardingOptionSelected event,
    Emitter<Under16OnboardingState> emit,
  ) {
    final nextStep = switch (event.option) {
      ParentInvolvementOption.recordTogether =>
        Under16OnboardingStep.consentVideo,
      ParentInvolvementOption.sendParentLink =>
        Under16OnboardingStep.consentVideo,
      ParentInvolvementOption.comeBackLater =>
        Under16OnboardingStep.confirmation,
    };

    emit(
      state.copyWith(
        selectedOption: event.option,
        step: nextStep,
      ),
    );
  }

  void _onVideoRecorded(
    Under16OnboardingVideoRecorded event,
    Emitter<Under16OnboardingState> emit,
  ) {
    emit(
      state.copyWith(
        videoPath: event.videoPath,
        step: Under16OnboardingStep.confirmation,
      ),
    );
  }

  void _onVideoRetakeRequested(
    Under16OnboardingVideoRetakeRequested event,
    Emitter<Under16OnboardingState> emit,
  ) {
    emit(
      state.copyWith(
        clearVideoPath: true,
        step: Under16OnboardingStep.consentVideo,
      ),
    );
  }

  void _onParentEmailEntered(
    Under16OnboardingParentEmailEntered event,
    Emitter<Under16OnboardingState> emit,
  ) {
    emit(state.copyWith(parentEmail: event.email));
  }

  void _onCompleted(
    Under16OnboardingCompleted event,
    Emitter<Under16OnboardingState> emit,
  ) {
    // In a future phase this will trigger account creation with the
    // under-16 flag. For now, just mark submitting so the UI can react.
    emit(state.copyWith(isSubmitting: true));
  }
}
