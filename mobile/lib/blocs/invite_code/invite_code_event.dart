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

  /// The invite code to claim.
  final String code;

  @override
  List<Object> get props => [code];
}

/// Reset the BLoC state to initial.
final class InviteCodeReset extends InviteCodeEvent {
  const InviteCodeReset();

  @override
  List<Object?> get props => [];
}
