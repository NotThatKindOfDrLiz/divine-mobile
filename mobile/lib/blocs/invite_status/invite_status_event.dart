// ABOUTME: Events for InviteStatusBloc
// ABOUTME: Sealed classes for type-safe event handling

part of 'invite_status_bloc.dart';

/// Base class for all invite status events.
sealed class InviteStatusEvent extends Equatable {
  const InviteStatusEvent();
}

/// Request to fetch the authenticated user's invite status from the server.
final class InviteStatusRequested extends InviteStatusEvent {
  const InviteStatusRequested();

  @override
  List<Object?> get props => [];
}
