// ABOUTME: Tests for WelcomeBloc
// ABOUTME: Verifies returning-user loading, dismissal, and auth action events

import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/welcome/welcome_bloc.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockAuthService extends Mock implements AuthService {}

const _testPubkeyHex =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

final _testProfile = UserProfile(
  pubkey: _testPubkeyHex,
  displayName: 'Test User',
  picture: 'https://example.com/avatar.png',
  nip05: 'testuser@example.com',
  rawData: const {},
  createdAt: DateTime(2024),
  eventId: 'e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8',
);

void main() {
  late SharedPreferences prefs;
  late _MockUserProfilesDao mockUserProfilesDao;
  late _MockAuthService mockAuthService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockUserProfilesDao = _MockUserProfilesDao();
    mockAuthService = _MockAuthService();

    when(() => mockAuthService.signInAutomatically()).thenAnswer((_) async {});
    when(
      () => mockAuthService.signOut(deleteKeys: true),
    ).thenAnswer((_) async {});
    when(() => mockAuthService.acceptTerms()).thenAnswer((_) async {});
  });

  WelcomeBloc buildBloc() => WelcomeBloc(
    sharedPreferences: prefs,
    userProfilesDao: mockUserProfilesDao,
    authService: mockAuthService,
  );

  group(WelcomeBloc, () {
    test('initial state is $WelcomeState with initial status', () {
      final bloc = buildBloc();
      expect(bloc.state, const WelcomeState());
      expect(bloc.state.status, WelcomeStatus.initial);
      bloc.close();
    });

    group('$WelcomeStarted', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with no returning user when no key in prefs',
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [const WelcomeState(status: WelcomeStatus.loaded)],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with returning user when key and profile exist',
        setUp: () async {
          await prefs.setString(kLastUserPubkeyHexKey, _testPubkeyHex);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) async => _testProfile);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          WelcomeState(
            status: WelcomeStatus.loaded,
            lastUserPubkeyHex: _testPubkeyHex,
            lastUserProfile: _testProfile,
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with pubkey but null profile when profile not cached',
        setUp: () async {
          await prefs.setString(kLastUserPubkeyHexKey, _testPubkeyHex);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) async => null);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            lastUserPubkeyHex: _testPubkeyHex,
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with pubkey when profile lookup throws',
        setUp: () async {
          await prefs.setString(kLastUserPubkeyHexKey, _testPubkeyHex);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenThrow(Exception('DB error'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            lastUserPubkeyHex: _testPubkeyHex,
          ),
        ],
      );
    });

    group('$WelcomeLastUserDismissed', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'clears returning user data and removes pref key',
        setUp: () async {
          await prefs.setString(kLastUserPubkeyHexKey, _testPubkeyHex);
        },
        seed: () => WelcomeState(
          status: WelcomeStatus.loaded,
          lastUserPubkeyHex: _testPubkeyHex,
          lastUserProfile: _testProfile,
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeLastUserDismissed()),
        expect: () => [const WelcomeState(status: WelcomeStatus.loaded)],
        verify: (_) {
          expect(prefs.getString(kLastUserPubkeyHexKey), isNull);
        },
      );
    });

    group('$WelcomeLogBackInRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'emits accepting and calls signInAutomatically',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [const WelcomeState(status: WelcomeStatus.accepting)],
        verify: (_) {
          verify(() => mockAuthService.signInAutomatically()).called(1);
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits error on signInAutomatically failure',
        setUp: () {
          when(
            () => mockAuthService.signInAutomatically(),
          ).thenThrow(Exception('Network error'));
        },
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(status: WelcomeStatus.accepting),
          const WelcomeState(
            status: WelcomeStatus.error,
            error: 'Failed to continue: Exception: Network error',
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'resets shouldNavigateToLoginOptions when dispatched after '
        '$WelcomeLoginOptionsRequested',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          shouldNavigateToLoginOptions: true,
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [const WelcomeState(status: WelcomeStatus.accepting)],
      );
    });

    group('$WelcomeCreateNewAccountRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'calls signOut with deleteKeys then signInAutomatically',
        build: buildBloc,
        seed: () => WelcomeState(
          status: WelcomeStatus.loaded,
          lastUserPubkeyHex: _testPubkeyHex,
          lastUserProfile: _testProfile,
        ),
        act: (bloc) => bloc.add(const WelcomeCreateNewAccountRequested()),
        expect: () => [
          WelcomeState(
            status: WelcomeStatus.accepting,
            lastUserPubkeyHex: _testPubkeyHex,
            lastUserProfile: _testProfile,
          ),
        ],
        verify: (_) {
          verifyInOrder([
            () => mockAuthService.signOut(deleteKeys: true),
            () => mockAuthService.signInAutomatically(),
          ]);
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits error on failure',
        setUp: () {
          when(
            () => mockAuthService.signOut(deleteKeys: true),
          ).thenThrow(Exception('Sign out failed'));
        },
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeCreateNewAccountRequested()),
        expect: () => [
          const WelcomeState(status: WelcomeStatus.accepting),
          const WelcomeState(
            status: WelcomeStatus.error,
            error: 'Failed to continue: Exception: Sign out failed',
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'resets shouldNavigateToLoginOptions when dispatched after '
        '$WelcomeLoginOptionsRequested',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          shouldNavigateToLoginOptions: true,
        ),
        act: (bloc) => bloc.add(const WelcomeCreateNewAccountRequested()),
        expect: () => [const WelcomeState(status: WelcomeStatus.accepting)],
      );
    });

    group('$WelcomeLoginOptionsRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'calls acceptTerms and emits shouldNavigateToLoginOptions',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeLoginOptionsRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            shouldNavigateToLoginOptions: true,
          ),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
      );
    });
  });

  group('$WelcomeState', () {
    test('hasReturningUser is true when lastUserPubkeyHex is set', () {
      const state = WelcomeState(lastUserPubkeyHex: _testPubkeyHex);
      expect(state.hasReturningUser, isTrue);
    });

    test('hasReturningUser is false when lastUserPubkeyHex is null', () {
      const state = WelcomeState();
      expect(state.hasReturningUser, isFalse);
    });

    test('isAccepting is true when status is accepting', () {
      const state = WelcomeState(status: WelcomeStatus.accepting);
      expect(state.isAccepting, isTrue);
    });

    test('copyWith clearLastUser removes user data', () {
      final state = WelcomeState(
        status: WelcomeStatus.loaded,
        lastUserPubkeyHex: _testPubkeyHex,
        lastUserProfile: _testProfile,
      );
      final cleared = state.copyWith(clearLastUser: true);
      expect(cleared.lastUserPubkeyHex, isNull);
      expect(cleared.lastUserProfile, isNull);
      expect(cleared.status, WelcomeStatus.loaded);
    });

    test('copyWith clearError removes error', () {
      const state = WelcomeState(
        status: WelcomeStatus.error,
        error: 'some error',
      );
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });
  });
}
