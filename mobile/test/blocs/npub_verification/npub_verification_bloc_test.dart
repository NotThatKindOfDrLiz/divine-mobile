// ABOUTME: Tests for NpubVerificationBloc
// ABOUTME: Verifies npub verification, skip invite, reset, and droppable
// transformer

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/models/npub_verification_result.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/services/npub_verification_service.dart';

class _MockNpubVerificationService extends Mock
    implements NpubVerificationService {}

class _MockNpubVerificationRepository extends Mock
    implements NpubVerificationRepository {}

const _testNpub =
    'npub1a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6';

void main() {
  group(NpubVerificationBloc, () {
    late _MockNpubVerificationService mockService;
    late _MockNpubVerificationRepository mockRepository;

    setUp(() {
      mockService = _MockNpubVerificationService();
      mockRepository = _MockNpubVerificationRepository();
    });

    NpubVerificationBloc buildBloc() => NpubVerificationBloc(
      verificationService: mockService,
      repository: mockRepository,
    );

    group('initial state', () {
      test('is $NpubVerificationState with initial status', () {
        final bloc = buildBloc();
        expect(bloc.state, const NpubVerificationState());
        expect(bloc.state.status, NpubVerificationStatus.initial);
        expect(bloc.state.skipInviteRequested, isFalse);
        expect(bloc.state.error, isNull);
        bloc.close();
      });
    });

    group('$NpubVerificationRequested', () {
      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits [verifying, verified] when verification succeeds '
        'with valid result',
        setUp: () {
          when(() => mockService.verifyNpub(_testNpub)).thenAnswer(
            (_) async =>
                const NpubVerificationResult(valid: true, message: 'OK'),
          );
          when(
            () => mockRepository.setVerified(_testNpub),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const NpubVerificationRequested(_testNpub)),
        expect: () => [
          const NpubVerificationState(status: NpubVerificationStatus.verifying),
          const NpubVerificationState(status: NpubVerificationStatus.verified),
        ],
        verify: (_) {
          verify(() => mockService.verifyNpub(_testNpub)).called(1);
          verify(() => mockRepository.setVerified(_testNpub)).called(1);
        },
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'clears skipInviteRequested on successful verification',
        setUp: () {
          when(
            () => mockService.verifyNpub(_testNpub),
          ).thenAnswer((_) async => const NpubVerificationResult(valid: true));
          when(
            () => mockRepository.setVerified(_testNpub),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        seed: () => const NpubVerificationState(skipInviteRequested: true),
        act: (bloc) => bloc.add(const NpubVerificationRequested(_testNpub)),
        expect: () => [
          const NpubVerificationState(
            status: NpubVerificationStatus.verifying,
            skipInviteRequested: true,
          ),
          const NpubVerificationState(status: NpubVerificationStatus.verified),
        ],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits [verifying, rejected] when verification result is invalid',
        setUp: () {
          when(() => mockService.verifyNpub(_testNpub)).thenAnswer(
            (_) async => const NpubVerificationResult(
              valid: false,
              message: 'Account not authorized',
            ),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const NpubVerificationRequested(_testNpub)),
        expect: () => [
          const NpubVerificationState(status: NpubVerificationStatus.verifying),
          const NpubVerificationState(
            status: NpubVerificationStatus.rejected,
            error: 'Account not authorized',
          ),
        ],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits [verifying, failed] when $NpubVerificationException is thrown',
        setUp: () {
          when(() => mockService.verifyNpub(_testNpub)).thenThrow(
            const NpubVerificationException('Server error', statusCode: 500),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const NpubVerificationRequested(_testNpub)),
        expect: () => [
          const NpubVerificationState(status: NpubVerificationStatus.verifying),
          const NpubVerificationState(
            status: NpubVerificationStatus.failed,
            error: 'Server error',
          ),
        ],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits [verifying, failed] with generic message '
        'when unexpected exception is thrown',
        setUp: () {
          when(
            () => mockService.verifyNpub(_testNpub),
          ).thenThrow(Exception('Something unexpected'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const NpubVerificationRequested(_testNpub)),
        expect: () => [
          const NpubVerificationState(status: NpubVerificationStatus.verifying),
          const NpubVerificationState(
            status: NpubVerificationStatus.failed,
            error: 'Verification failed. Please try again.',
          ),
        ],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'clears previous error when new verification is requested',
        setUp: () {
          when(
            () => mockService.verifyNpub(_testNpub),
          ).thenAnswer((_) async => const NpubVerificationResult(valid: true));
          when(
            () => mockRepository.setVerified(_testNpub),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        seed: () => const NpubVerificationState(
          status: NpubVerificationStatus.failed,
          error: 'Previous error',
        ),
        act: (bloc) => bloc.add(const NpubVerificationRequested(_testNpub)),
        expect: () => [
          const NpubVerificationState(status: NpubVerificationStatus.verifying),
          const NpubVerificationState(status: NpubVerificationStatus.verified),
        ],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'uses droppable transformer - drops events while processing',
        setUp: () {
          when(() => mockService.verifyNpub(_testNpub)).thenAnswer((_) async {
            // First call takes time, second would be dropped
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return const NpubVerificationResult(valid: true);
          });
          when(
            () => mockRepository.setVerified(_testNpub),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) {
          // Add two events rapidly - second should be dropped
          bloc
            ..add(const NpubVerificationRequested(_testNpub))
            ..add(const NpubVerificationRequested(_testNpub));
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          const NpubVerificationState(status: NpubVerificationStatus.verifying),
          const NpubVerificationState(status: NpubVerificationStatus.verified),
        ],
        verify: (_) {
          // Only called once because the second event was dropped
          verify(() => mockService.verifyNpub(_testNpub)).called(1);
        },
      );
    });

    group('$NpubVerificationSkipInviteSet', () {
      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits state with skipInviteRequested set to true',
        build: buildBloc,
        act: (bloc) => bloc.add(const NpubVerificationSkipInviteSet()),
        expect: () => [const NpubVerificationState(skipInviteRequested: true)],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'preserves existing status when setting skipInviteRequested',
        build: buildBloc,
        seed: () => const NpubVerificationState(
          status: NpubVerificationStatus.failed,
          error: 'Some error',
        ),
        act: (bloc) => bloc.add(const NpubVerificationSkipInviteSet()),
        expect: () => [
          const NpubVerificationState(
            status: NpubVerificationStatus.failed,
            error: 'Some error',
            skipInviteRequested: true,
          ),
        ],
      );
    });

    group('$NpubVerificationSkipInviteCleared', () {
      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits state with skipInviteRequested set to false',
        build: buildBloc,
        seed: () => const NpubVerificationState(skipInviteRequested: true),
        act: (bloc) => bloc.add(const NpubVerificationSkipInviteCleared()),
        expect: () => [const NpubVerificationState()],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'preserves existing status when clearing skipInviteRequested',
        build: buildBloc,
        seed: () => const NpubVerificationState(
          status: NpubVerificationStatus.rejected,
          error: 'Rejected',
          skipInviteRequested: true,
        ),
        act: (bloc) => bloc.add(const NpubVerificationSkipInviteCleared()),
        expect: () => [
          const NpubVerificationState(
            status: NpubVerificationStatus.rejected,
            error: 'Rejected',
          ),
        ],
      );
    });

    group('$NpubVerificationReset', () {
      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits initial state when reset from verified state',
        build: buildBloc,
        seed: () => const NpubVerificationState(
          status: NpubVerificationStatus.verified,
          skipInviteRequested: true,
        ),
        act: (bloc) => bloc.add(const NpubVerificationReset()),
        expect: () => [const NpubVerificationState()],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits initial state when reset from failed state with error',
        build: buildBloc,
        seed: () => const NpubVerificationState(
          status: NpubVerificationStatus.failed,
          error: 'Server error',
          skipInviteRequested: true,
        ),
        act: (bloc) => bloc.add(const NpubVerificationReset()),
        expect: () => [const NpubVerificationState()],
      );

      blocTest<NpubVerificationBloc, NpubVerificationState>(
        'emits initial state even when already in initial state',
        build: buildBloc,
        act: (bloc) => bloc.add(const NpubVerificationReset()),
        expect: () => [const NpubVerificationState()],
      );
    });

    group('isNpubVerified', () {
      test('returns false when npub is null', () {
        final bloc = buildBloc();
        expect(bloc.isNpubVerified(null), isFalse);
        bloc.close();
      });

      test('returns true when repository reports npub is verified', () {
        when(() => mockRepository.isVerified(_testNpub)).thenReturn(true);

        final bloc = buildBloc();
        expect(bloc.isNpubVerified(_testNpub), isTrue);
        verify(() => mockRepository.isVerified(_testNpub)).called(1);
        bloc.close();
      });

      test('returns false when repository reports npub is not verified', () {
        when(() => mockRepository.isVerified(_testNpub)).thenReturn(false);

        final bloc = buildBloc();
        expect(bloc.isNpubVerified(_testNpub), isFalse);
        verify(() => mockRepository.isVerified(_testNpub)).called(1);
        bloc.close();
      });
    });

    group('skipInviteRequested', () {
      test('returns false for initial state', () {
        final bloc = buildBloc();
        expect(bloc.skipInviteRequested, isFalse);
        bloc.close();
      });

      test(
        'returns true after $NpubVerificationSkipInviteSet is added',
        () async {
          final bloc = buildBloc();
          bloc.add(const NpubVerificationSkipInviteSet());
          await Future<void>.delayed(Duration.zero);
          expect(bloc.skipInviteRequested, isTrue);
          bloc.close();
        },
      );
    });
  });

  group('$NpubVerificationState', () {
    test('supports value equality', () {
      expect(
        const NpubVerificationState(),
        equals(const NpubVerificationState()),
      );
    });

    test('states with different status are not equal', () {
      expect(
        const NpubVerificationState(),
        isNot(
          equals(
            const NpubVerificationState(
              status: NpubVerificationStatus.verified,
            ),
          ),
        ),
      );
    });

    test('states with different skipInviteRequested are not equal', () {
      expect(
        const NpubVerificationState(),
        isNot(equals(const NpubVerificationState(skipInviteRequested: true))),
      );
    });

    test('states with different error are not equal', () {
      expect(
        const NpubVerificationState(),
        isNot(equals(const NpubVerificationState(error: 'error'))),
      );
    });

    group('convenience getters', () {
      test('isVerifying returns true for verifying status', () {
        const state = NpubVerificationState(
          status: NpubVerificationStatus.verifying,
        );
        expect(state.isVerifying, isTrue);
        expect(state.isVerified, isFalse);
        expect(state.isRejected, isFalse);
        expect(state.isFailed, isFalse);
      });

      test('isVerified returns true for verified status', () {
        const state = NpubVerificationState(
          status: NpubVerificationStatus.verified,
        );
        expect(state.isVerifying, isFalse);
        expect(state.isVerified, isTrue);
        expect(state.isRejected, isFalse);
        expect(state.isFailed, isFalse);
      });

      test('isRejected returns true for rejected status', () {
        const state = NpubVerificationState(
          status: NpubVerificationStatus.rejected,
        );
        expect(state.isVerifying, isFalse);
        expect(state.isVerified, isFalse);
        expect(state.isRejected, isTrue);
        expect(state.isFailed, isFalse);
      });

      test('isFailed returns true for failed status', () {
        const state = NpubVerificationState(
          status: NpubVerificationStatus.failed,
        );
        expect(state.isVerifying, isFalse);
        expect(state.isVerified, isFalse);
        expect(state.isRejected, isFalse);
        expect(state.isFailed, isTrue);
      });
    });

    group('copyWith', () {
      test('copies with new status', () {
        const state = NpubVerificationState();
        final copied = state.copyWith(status: NpubVerificationStatus.verified);
        expect(copied.status, NpubVerificationStatus.verified);
        expect(copied.skipInviteRequested, isFalse);
        expect(copied.error, isNull);
      });

      test('copies with new skipInviteRequested', () {
        const state = NpubVerificationState();
        final copied = state.copyWith(skipInviteRequested: true);
        expect(copied.skipInviteRequested, isTrue);
        expect(copied.status, NpubVerificationStatus.initial);
      });

      test('copies with new error', () {
        const state = NpubVerificationState();
        final copied = state.copyWith(error: 'test error');
        expect(copied.error, equals('test error'));
      });

      test('clearError removes existing error', () {
        const state = NpubVerificationState(error: 'existing error');
        final copied = state.copyWith(clearError: true);
        expect(copied.error, isNull);
      });

      test('clearError takes priority over new error', () {
        const state = NpubVerificationState(error: 'existing error');
        final copied = state.copyWith(error: 'new error', clearError: true);
        expect(copied.error, isNull);
      });

      test('preserves all fields when no arguments provided', () {
        const state = NpubVerificationState(
          status: NpubVerificationStatus.verified,
          skipInviteRequested: true,
          error: 'some error',
        );
        final copied = state.copyWith();
        expect(copied, equals(state));
      });
    });
  });

  group('$NpubVerificationEvent', () {
    test('$NpubVerificationRequested supports value equality', () {
      expect(
        const NpubVerificationRequested(_testNpub),
        equals(const NpubVerificationRequested(_testNpub)),
      );
    });

    test('$NpubVerificationRequested with different npub are not equal', () {
      expect(
        const NpubVerificationRequested(_testNpub),
        isNot(
          equals(
            const NpubVerificationRequested(
              'npub1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
            ),
          ),
        ),
      );
    });

    test('$NpubVerificationSkipInviteSet supports value equality', () {
      expect(
        const NpubVerificationSkipInviteSet(),
        equals(const NpubVerificationSkipInviteSet()),
      );
    });

    test('$NpubVerificationSkipInviteCleared supports value equality', () {
      expect(
        const NpubVerificationSkipInviteCleared(),
        equals(const NpubVerificationSkipInviteCleared()),
      );
    });

    test('$NpubVerificationReset supports value equality', () {
      expect(
        const NpubVerificationReset(),
        equals(const NpubVerificationReset()),
      );
    });
  });
}
