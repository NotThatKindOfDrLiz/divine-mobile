// ABOUTME: Events for NpubVerificationBloc
// ABOUTME: Sealed classes for type-safe event handling

part of 'npub_verification_bloc.dart';

/// Base class for all npub verification events.
sealed class NpubVerificationEvent extends Equatable {
  const NpubVerificationEvent();
}

/// Request to verify an npub with the server.
///
/// Triggers API call to verify the npub is authorized for access.
final class NpubVerificationRequested extends NpubVerificationEvent {
  const NpubVerificationRequested(this.npub);

  /// The npub to verify.
  final String npub;

  @override
  List<Object> get props => [npub];
}

/// Set the skip invite flag.
///
/// Called when user clicks "Sign In" on the invite screen,
/// indicating they want to bypass invite code entry.
final class NpubVerificationSkipInviteSet extends NpubVerificationEvent {
  const NpubVerificationSkipInviteSet();

  @override
  List<Object?> get props => [];
}

/// Clear the skip invite flag.
///
/// Called after successful verification or on verification failure
/// to reset the flow state.
final class NpubVerificationSkipInviteCleared extends NpubVerificationEvent {
  const NpubVerificationSkipInviteCleared();

  @override
  List<Object?> get props => [];
}

/// Reset the BLoC state to initial.
final class NpubVerificationReset extends NpubVerificationEvent {
  const NpubVerificationReset();

  @override
  List<Object?> get props => [];
}
