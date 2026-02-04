// ABOUTME: Events for InviteCodeBloc
// ABOUTME: Sealed classes for type-safe event handling

part of 'invite_code_bloc.dart';

/// Base class for all invite code events.
sealed class InviteCodeEvent extends Equatable {
  const InviteCodeEvent();
}

/// Request to claim an invite code.
///
/// Triggers API call to verify and claim the code.
final class InviteCodeClaimRequested extends InviteCodeEvent {
  const InviteCodeClaimRequested(this.code);

  /// The 8-character invite code to claim.
  final String code;

  @override
  List<Object> get props => [code];
}

/// Set a pending invite code from a deep link.
///
/// Used when the app receives a deep link like:
/// `https://divine.video/invite/ABC12345`
final class InviteCodePendingSet extends InviteCodeEvent {
  const InviteCodePendingSet(this.code);

  /// The invite code from the deep link.
  final String code;

  @override
  List<Object> get props => [code];
}

/// Clear the pending invite code after processing.
final class InviteCodePendingCleared extends InviteCodeEvent {
  const InviteCodePendingCleared();

  @override
  List<Object?> get props => [];
}

/// Reset the BLoC state to initial.
final class InviteCodeReset extends InviteCodeEvent {
  const InviteCodeReset();

  @override
  List<Object?> get props => [];
}
