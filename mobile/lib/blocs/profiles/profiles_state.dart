// ABOUTME: State for ProfilesBloc - accumulating map of pubkey → UserProfile
// ABOUTME: Single class with enum-less design; profiles grow over app lifetime

part of 'profiles_bloc.dart';

/// State holding all fetched profiles.
///
/// Profiles accumulate over the app's lifetime. There is no global
/// loading/error status — each pubkey is either present in [profiles]
/// or not yet fetched.
class ProfilesState extends Equatable {
  const ProfilesState({
    this.profiles = const {},
    this.requestedPubkeys = const {},
  });

  /// Map of pubkey → [UserProfile] for all profiles fetched so far.
  final Map<String, UserProfile> profiles;

  /// Set of pubkeys that have already been requested. Used to make
  /// [ProfileRequested] idempotent — a second event for the same
  /// pubkey is a no-op.
  final Set<String> requestedPubkeys;

  ProfilesState copyWith({
    Map<String, UserProfile>? profiles,
    Set<String>? requestedPubkeys,
  }) {
    return ProfilesState(
      profiles: profiles ?? this.profiles,
      requestedPubkeys: requestedPubkeys ?? this.requestedPubkeys,
    );
  }

  @override
  List<Object?> get props => [profiles, requestedPubkeys];
}
