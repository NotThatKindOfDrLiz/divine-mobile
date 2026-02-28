// ABOUTME: App-level BLoC for inline profile display (name, avatar).
// ABOUTME: One-shot cache+fetch per pubkey, no persistent streams.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

part 'profiles_event.dart';
part 'profiles_state.dart';

/// App-level BLoC that serves as a single source of truth for inline
/// profile display (display name, avatar) across the entire app.
///
/// Provided once at [AppShell]. Widgets dispatch [ProfileRequested]
/// and use `context.select` for efficient per-pubkey rebuilds.
class ProfilesBloc extends Bloc<ProfilesEvent, ProfilesState> {
  ProfilesBloc({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository,
      super(const ProfilesState()) {
    on<ProfileRequested>(_onProfileRequested);
    on<ProfileRefreshRequested>(_onProfileRefreshRequested);
  }

  final ProfileRepository _profileRepository;

  Future<void> _onProfileRequested(
    ProfileRequested event,
    Emitter<ProfilesState> emit,
  ) async {
    final pubkey = event.pubkey;

    // Idempotent — skip if already requested
    if (state.requestedPubkeys.contains(pubkey)) return;

    // Mark as requested immediately to prevent duplicate fetches
    emit(
      state.copyWith(
        requestedPubkeys: {...state.requestedPubkeys, pubkey},
      ),
    );

    // 1. Emit cached profile immediately if available
    try {
      final cached = await _profileRepository.getCachedProfile(
        pubkey: pubkey,
      );
      if (cached != null) {
        emit(
          state.copyWith(profiles: {...state.profiles, pubkey: cached}),
        );
      }

      // 2. Fetch fresh from relay and emit if returned non-null
      final fresh = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );
      if (fresh != null) {
        emit(
          state.copyWith(profiles: {...state.profiles, pubkey: fresh}),
        );
      }
    } on Exception {
      // Network errors are non-fatal — cached profile (if any) remains
    }
  }

  Future<void> _onProfileRefreshRequested(
    ProfileRefreshRequested event,
    Emitter<ProfilesState> emit,
  ) async {
    try {
      final fresh = await _profileRepository.fetchFreshProfile(
        pubkey: event.pubkey,
      );
      if (fresh != null) {
        emit(
          state.copyWith(
            profiles: {...state.profiles, event.pubkey: fresh},
          ),
        );
      }
    } on Exception {
      // Non-fatal — existing profile (if any) remains
    }
  }
}
