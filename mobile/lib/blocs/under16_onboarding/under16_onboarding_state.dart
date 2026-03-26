// ABOUTME: State for the under-16 PRR-informed onboarding flow
// ABOUTME: Single class with status enum — data persists across steps

import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/under16_onboarding/under16_onboarding_event.dart';

/// The current step in the under-16 onboarding flow.
enum Under16OnboardingStep {
  /// PRR Level 1 — Casual Engagement (Reflect).
  /// Educational screen explaining why we ask and why honesty matters.
  honesty,

  /// PRR Level 2 — Coached Engagement (Redirect).
  /// Choose how to involve a parent.
  options,

  /// Video recording step (for recordTogether or sendParentLink paths).
  consentVideo,

  /// Safety and education screen before account creation.
  confirmation,
}

class Under16OnboardingState extends Equatable {
  const Under16OnboardingState({
    this.step = Under16OnboardingStep.honesty,
    this.selectedOption,
    this.videoPath,
    this.parentEmail,
    this.isSubmitting = false,
  });

  /// Current step in the flow.
  final Under16OnboardingStep step;

  /// Which parent involvement option the user chose.
  final ParentInvolvementOption? selectedOption;

  /// Local path to the recorded consent video (if any).
  final String? videoPath;

  /// Parent's email address (for the sendParentLink path).
  final String? parentEmail;

  /// Whether a submission (e.g. sending parent invite) is in progress.
  final bool isSubmitting;

  /// Whether a consent video has been recorded.
  bool get hasVideo => videoPath != null;

  /// Whether the flow is ready to proceed to account creation.
  bool get isReadyForAccountCreation =>
      step == Under16OnboardingStep.confirmation &&
      (selectedOption == ParentInvolvementOption.recordTogether && hasVideo ||
          selectedOption == ParentInvolvementOption.sendParentLink &&
              parentEmail != null ||
          selectedOption == ParentInvolvementOption.comeBackLater);

  Under16OnboardingState copyWith({
    Under16OnboardingStep? step,
    ParentInvolvementOption? selectedOption,
    String? videoPath,
    bool clearVideoPath = false,
    String? parentEmail,
    bool? isSubmitting,
  }) {
    return Under16OnboardingState(
      step: step ?? this.step,
      selectedOption: selectedOption ?? this.selectedOption,
      videoPath: clearVideoPath ? null : (videoPath ?? this.videoPath),
      parentEmail: parentEmail ?? this.parentEmail,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [
    step,
    selectedOption,
    videoPath,
    parentEmail,
    isSubmitting,
  ];
}
