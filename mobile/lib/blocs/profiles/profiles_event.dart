// ABOUTME: Events for ProfilesBloc - app-level profile lookup
// ABOUTME: Idempotent ProfileRequested + force-refresh ProfileRefreshRequested

part of 'profiles_bloc.dart';

/// Base class for all profiles events.
sealed class ProfilesEvent extends Equatable {
  const ProfilesEvent();

  @override
  List<Object?> get props => [];
}

/// Request a profile by pubkey. Idempotent — second request for the same
/// pubkey is a no-op (the profile is already being fetched or is cached).
final class ProfileRequested extends ProfilesEvent {
  const ProfileRequested({required this.pubkey});

  /// The 64-character hex pubkey to look up.
  final String pubkey;

  @override
  List<Object?> get props => [pubkey];
}

/// Force re-fetch a profile from relays, ignoring the idempotency guard.
/// Use after the user edits their own profile or pulls to refresh.
final class ProfileRefreshRequested extends ProfilesEvent {
  const ProfileRefreshRequested({required this.pubkey});

  /// The 64-character hex pubkey to refresh.
  final String pubkey;

  @override
  List<Object?> get props => [pubkey];
}
