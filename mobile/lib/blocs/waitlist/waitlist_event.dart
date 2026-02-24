// ABOUTME: Events for WaitlistBloc
// ABOUTME: Sealed classes for type-safe event handling

part of 'waitlist_bloc.dart';

/// Base class for all waitlist events.
sealed class WaitlistEvent extends Equatable {
  const WaitlistEvent();
}

/// Request to join the waitlist with an email address.
final class WaitlistEmailSubmitted extends WaitlistEvent {
  const WaitlistEmailSubmitted(this.email);

  /// The email address to add to the waitlist.
  final String email;

  @override
  List<Object> get props => [email];
}

/// Reset the BLoC state to initial.
final class WaitlistReset extends WaitlistEvent {
  const WaitlistReset();

  @override
  List<Object?> get props => [];
}
