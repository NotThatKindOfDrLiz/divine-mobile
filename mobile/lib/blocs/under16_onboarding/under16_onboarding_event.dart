// ABOUTME: Events for the under-16 PRR-informed onboarding flow
// ABOUTME: Drives the multi-step flow from age acknowledgment through
// ABOUTME: parental consent video to account creation

import 'package:equatable/equatable.dart';

sealed class Under16OnboardingEvent extends Equatable {
  const Under16OnboardingEvent();

  @override
  List<Object?> get props => const [];
}

/// User tapped "What if I'm not 16 yet?" — enter the flow.
class Under16OnboardingStarted extends Under16OnboardingEvent {
  const Under16OnboardingStarted();
}

/// User selected how they want to involve their parent.
class Under16OnboardingOptionSelected extends Under16OnboardingEvent {
  const Under16OnboardingOptionSelected(this.option);

  final ParentInvolvementOption option;

  @override
  List<Object?> get props => [option];
}

/// User recorded a consent video.
class Under16OnboardingVideoRecorded extends Under16OnboardingEvent {
  const Under16OnboardingVideoRecorded(this.videoPath);

  final String videoPath;

  @override
  List<Object?> get props => [videoPath];
}

/// User wants to re-record the consent video.
class Under16OnboardingVideoRetakeRequested extends Under16OnboardingEvent {
  const Under16OnboardingVideoRetakeRequested();
}

/// User entered a parent's email for the invite path.
class Under16OnboardingParentEmailEntered extends Under16OnboardingEvent {
  const Under16OnboardingParentEmailEntered(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// User completed the safety/education screen and is ready to create account.
class Under16OnboardingCompleted extends Under16OnboardingEvent {
  const Under16OnboardingCompleted();
}

/// The ways a child can involve their parent in the consent process.
///
/// Maps to PRR Level 2 (Coached Engagement) — bringing in a trusted adult.
enum ParentInvolvementOption {
  /// Record a video together with parent present.
  recordTogether,

  /// Send parent a link so they can review and record consent independently.
  sendParentLink,

  /// Save progress and come back later with parent.
  comeBackLater,
}
