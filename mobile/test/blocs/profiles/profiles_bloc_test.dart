// ABOUTME: Unit tests for ProfilesBloc
// ABOUTME: Tests cache+fetch, idempotency, refresh, and error handling

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profiles/profiles_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group(ProfilesBloc, () {
    late _MockProfileRepository mockRepo;

    const pubkeyA =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const pubkeyB =
        'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';

    final profileA = UserProfile(
      pubkey: pubkeyA,
      displayName: 'Alice',
      rawData: const {},
      createdAt: DateTime(2024),
      eventId:
          'event_a_123456789012345678901234567890123456789012345678901234567',
    );

    final freshProfileA = UserProfile(
      pubkey: pubkeyA,
      displayName: 'Alice Updated',
      rawData: const {},
      createdAt: DateTime(2024),
      eventId:
          'event_a_fresh_2345678901234567890123456789012345678901234567890123',
    );

    final profileB = UserProfile(
      pubkey: pubkeyB,
      displayName: 'Bob',
      rawData: const {},
      createdAt: DateTime(2024),
      eventId:
          'event_b_123456789012345678901234567890123456789012345678901234567',
    );

    setUp(() {
      mockRepo = _MockProfileRepository();
    });

    ProfilesBloc createBloc() => ProfilesBloc(profileRepository: mockRepo);

    test('initial state is empty $ProfilesState', () {
      final bloc = createBloc();
      expect(bloc.state, equals(const ProfilesState()));
      expect(bloc.state.profiles, isEmpty);
      expect(bloc.state.requestedPubkeys, isEmpty);
      bloc.close();
    });

    group('$ProfileRequested', () {
      blocTest<ProfilesBloc, ProfilesState>(
        'emits cached profile then fresh profile',
        setUp: () {
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => profileA);
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => freshProfileA);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRequested(pubkey: pubkeyA)),
        expect: () => [
          // 1. Mark as requested
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          // 2. Cached profile emitted
          ProfilesState(
            profiles: {pubkeyA: profileA},
            requestedPubkeys: const {pubkeyA},
          ),
          // 3. Fresh profile emitted
          ProfilesState(
            profiles: {pubkeyA: freshProfileA},
            requestedPubkeys: const {pubkeyA},
          ),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'emits only fresh profile when nothing cached',
        setUp: () {
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => null);
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => freshProfileA);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRequested(pubkey: pubkeyA)),
        expect: () => [
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          ProfilesState(
            profiles: {pubkeyA: freshProfileA},
            requestedPubkeys: const {pubkeyA},
          ),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'emits only cached profile when fetch returns null',
        setUp: () {
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => profileA);
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRequested(pubkey: pubkeyA)),
        expect: () => [
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          ProfilesState(
            profiles: {pubkeyA: profileA},
            requestedPubkeys: const {pubkeyA},
          ),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'emits only requestedPubkeys when both cache and fetch return null',
        setUp: () {
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => null);
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRequested(pubkey: pubkeyA)),
        expect: () => [
          const ProfilesState(requestedPubkeys: {pubkeyA}),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'is idempotent — second request for same pubkey is no-op',
        setUp: () {
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => profileA);
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) {
          bloc
            ..add(const ProfileRequested(pubkey: pubkeyA))
            ..add(const ProfileRequested(pubkey: pubkeyA));
        },
        expect: () => [
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          ProfilesState(
            profiles: {pubkeyA: profileA},
            requestedPubkeys: const {pubkeyA},
          ),
        ],
        verify: (_) {
          verify(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).called(1);
        },
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'handles multiple different pubkeys',
        setUp: () {
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => profileA);
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => null);
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyB),
          ).thenAnswer((_) async => profileB);
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyB),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) {
          bloc
            ..add(const ProfileRequested(pubkey: pubkeyA))
            ..add(const ProfileRequested(pubkey: pubkeyB));
        },
        expect: () => [
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          ProfilesState(
            profiles: {pubkeyA: profileA},
            requestedPubkeys: const {pubkeyA},
          ),
          ProfilesState(
            profiles: {pubkeyA: profileA},
            requestedPubkeys: const {pubkeyA, pubkeyB},
          ),
          ProfilesState(
            profiles: {pubkeyA: profileA, pubkeyB: profileB},
            requestedPubkeys: const {pubkeyA, pubkeyB},
          ),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'removes pubkey from requestedPubkeys on getCachedProfile exception',
        setUp: () {
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenThrow(Exception('DB error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRequested(pubkey: pubkeyA)),
        expect: () => [
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          const ProfilesState(),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'removes pubkey from requestedPubkeys on fetchFreshProfile exception',
        setUp: () {
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => profileA);
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRequested(pubkey: pubkeyA)),
        expect: () => [
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          ProfilesState(
            profiles: {pubkeyA: profileA},
            requestedPubkeys: const {pubkeyA},
          ),
          ProfilesState(profiles: {pubkeyA: profileA}),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'allows retry after transient failure',
        setUp: () {
          var callCount = 0;
          when(
            () => mockRepo.getCachedProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) throw Exception('DB error');
            return profileA;
          });
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ProfileRequested(pubkey: pubkeyA));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const ProfileRequested(pubkey: pubkeyA));
        },
        expect: () => [
          // First attempt: mark requested, then fail and remove
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          const ProfilesState(),
          // Retry: mark requested again, then succeed
          const ProfilesState(requestedPubkeys: {pubkeyA}),
          ProfilesState(
            profiles: {pubkeyA: profileA},
            requestedPubkeys: const {pubkeyA},
          ),
        ],
      );
    });

    group('$ProfileRefreshRequested', () {
      blocTest<ProfilesBloc, ProfilesState>(
        'updates existing profile in map',
        seed: () => ProfilesState(
          profiles: {pubkeyA: profileA},
          requestedPubkeys: const {pubkeyA},
        ),
        setUp: () {
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => freshProfileA);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileRefreshRequested(pubkey: pubkeyA),
        ),
        expect: () => [
          ProfilesState(
            profiles: {pubkeyA: freshProfileA},
            requestedPubkeys: const {pubkeyA},
          ),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'adds profile even if not previously requested',
        setUp: () {
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => freshProfileA);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileRefreshRequested(pubkey: pubkeyA),
        ),
        expect: () => [
          ProfilesState(
            profiles: {pubkeyA: freshProfileA},
          ),
        ],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'does not emit when fetch returns null',
        seed: () => ProfilesState(
          profiles: {pubkeyA: profileA},
          requestedPubkeys: const {pubkeyA},
        ),
        setUp: () {
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileRefreshRequested(pubkey: pubkeyA),
        ),
        expect: () => <ProfilesState>[],
      );

      blocTest<ProfilesBloc, ProfilesState>(
        'handles exception gracefully',
        seed: () => ProfilesState(
          profiles: {pubkeyA: profileA},
          requestedPubkeys: const {pubkeyA},
        ),
        setUp: () {
          when(
            () => mockRepo.fetchFreshProfile(pubkey: pubkeyA),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileRefreshRequested(pubkey: pubkeyA),
        ),
        expect: () => <ProfilesState>[],
      );
    });

    group('$ProfilesState', () {
      test('supports value equality', () {
        expect(const ProfilesState(), equals(const ProfilesState()));
      });

      test('copyWith returns same instance when no changes', () {
        const state = ProfilesState();
        expect(state.copyWith(), equals(state));
      });

      test('copyWith updates profiles', () {
        const state = ProfilesState();
        final updated = state.copyWith(
          profiles: {pubkeyA: profileA},
        );
        expect(updated.profiles, {pubkeyA: profileA});
        expect(updated.requestedPubkeys, isEmpty);
      });

      test('copyWith updates requestedPubkeys', () {
        const state = ProfilesState();
        final updated = state.copyWith(
          requestedPubkeys: {pubkeyA},
        );
        expect(updated.profiles, isEmpty);
        expect(updated.requestedPubkeys, {pubkeyA});
      });
    });

    group('$ProfilesEvent', () {
      test('$ProfileRequested supports value equality', () {
        expect(
          const ProfileRequested(pubkey: pubkeyA),
          equals(const ProfileRequested(pubkey: pubkeyA)),
        );
        expect(
          const ProfileRequested(pubkey: pubkeyA),
          isNot(equals(const ProfileRequested(pubkey: pubkeyB))),
        );
      });

      test('$ProfileRefreshRequested supports value equality', () {
        expect(
          const ProfileRefreshRequested(pubkey: pubkeyA),
          equals(const ProfileRefreshRequested(pubkey: pubkeyA)),
        );
        expect(
          const ProfileRefreshRequested(pubkey: pubkeyA),
          isNot(equals(const ProfileRefreshRequested(pubkey: pubkeyB))),
        );
      });
    });
  });
}
