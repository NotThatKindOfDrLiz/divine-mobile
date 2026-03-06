// ABOUTME: Tests for InviteCodeBloc
// ABOUTME: Verifies claim flow, error handling, and reset behavior

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_code/invite_code_bloc.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/services/invite_code_service.dart';

class _MockInviteCodeService extends Mock implements InviteCodeService {}

class _MockInviteCodeRepository extends Mock implements InviteCodeRepository {}

void main() {
  late _MockInviteCodeService mockService;
  late _MockInviteCodeRepository mockRepository;

  setUp(() {
    mockService = _MockInviteCodeService();
    mockRepository = _MockInviteCodeRepository();

    when(() => mockRepository.hasClaimedCode).thenReturn(false);
    when(
      () => mockRepository.setClaimedCode(any()),
    ).thenAnswer((_) async {});
  });

  InviteCodeBloc buildBloc() => InviteCodeBloc(
    inviteCodeService: mockService,
    repository: mockRepository,
  );

  group(InviteCodeBloc, () {
    test('initial state has correct defaults', () {
      final bloc = buildBloc();

      expect(bloc.state.status, equals(InviteCodeStatus.initial));
      expect(bloc.state.hasClaimedCode, isFalse);
      expect(bloc.state.result, isNull);
      expect(bloc.state.error, isNull);
      expect(bloc.state.isLoading, isFalse);

      bloc.close();
    });

    test('initial state reflects repository hasClaimedCode=true', () {
      when(() => mockRepository.hasClaimedCode).thenReturn(true);

      final bloc = buildBloc();

      expect(bloc.state.hasClaimedCode, isTrue);
      expect(bloc.state.status, equals(InviteCodeStatus.initial));

      bloc.close();
    });

    group('hasClaimedCode', () {
      test('delegates to repository when false', () {
        when(() => mockRepository.hasClaimedCode).thenReturn(false);

        final bloc = buildBloc();

        expect(bloc.hasClaimedCode, isFalse);
        verify(() => mockRepository.hasClaimedCode).called(greaterThan(0));

        bloc.close();
      });

      test('delegates to repository when true', () {
        when(() => mockRepository.hasClaimedCode).thenReturn(true);

        final bloc = buildBloc();

        expect(bloc.hasClaimedCode, isTrue);

        bloc.close();
      });
    });

    group('$InviteCodeClaimRequested', () {
      const validResult = InviteCodeResult(
        valid: true,
        message: 'Code claimed',
        code: 'DIVINE-2024',
        remainingUses: 0,
      );

      const invalidResult = InviteCodeResult(
        valid: false,
        message: 'Code expired',
        code: 'EXPIRED-CODE',
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'emits loading then success on valid claim',
        setUp: () {
          when(
            () => mockService.claimCode('DIVINE-2024'),
          ).thenAnswer((_) async => validResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested('DIVINE-2024')),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.success,
            hasClaimedCode: true,
            result: validResult,
          ),
        ],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'calls repository.setClaimedCode on success',
        setUp: () {
          when(
            () => mockService.claimCode('DIVINE-2024'),
          ).thenAnswer((_) async => validResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested('DIVINE-2024')),
        verify: (_) {
          verify(
            () => mockRepository.setClaimedCode('DIVINE-2024'),
          ).called(1);
        },
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'emits loading then failure on invalid claim',
        setUp: () {
          when(
            () => mockService.claimCode('EXPIRED-CODE'),
          ).thenAnswer((_) async => invalidResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested('EXPIRED-CODE')),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.failure,
            result: invalidResult,
            error: 'Code expired',
          ),
        ],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'does not call repository.setClaimedCode on invalid claim',
        setUp: () {
          when(
            () => mockService.claimCode('EXPIRED-CODE'),
          ).thenAnswer((_) async => invalidResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested('EXPIRED-CODE')),
        verify: (_) {
          verifyNever(() => mockRepository.setClaimedCode(any()));
        },
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'emits loading then failure on $InviteCodeException',
        setUp: () {
          when(
            () => mockService.claimCode('CODE'),
          ).thenThrow(
            const InviteCodeException('Request timed out. Please try again.'),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested('CODE')),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.failure,
            error: 'Request timed out. Please try again.',
          ),
        ],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'emits loading then failure on unexpected exception',
        setUp: () {
          when(
            () => mockService.claimCode('CODE'),
          ).thenThrow(Exception('Unexpected error'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested('CODE')),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.failure,
            error: 'An unexpected error occurred. Please try again.',
          ),
        ],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'clears previous error when loading',
        setUp: () {
          when(
            () => mockService.claimCode('CODE'),
          ).thenAnswer((_) async => validResult);
        },
        seed: () => const InviteCodeState(
          status: InviteCodeStatus.failure,
          error: 'Previous error',
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested('CODE')),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.success,
            hasClaimedCode: true,
            result: validResult,
          ),
        ],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'uses default error message when invalid result has no message',
        setUp: () {
          when(
            () => mockService.claimCode('CODE'),
          ).thenAnswer(
            (_) async => const InviteCodeResult(valid: false),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested('CODE')),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.failure,
            result: InviteCodeResult(valid: false),
            error: 'Code not found. Please try again.',
          ),
        ],
      );
    });

    group('$InviteCodeReset', () {
      blocTest<InviteCodeBloc, InviteCodeState>(
        'resets to initial state',
        seed: () => const InviteCodeState(
          status: InviteCodeStatus.failure,
          error: 'Some error',
          hasClaimedCode: true,
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeReset()),
        expect: () => [const InviteCodeState()],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'reflects current repository state after reset',
        setUp: () {
          when(() => mockRepository.hasClaimedCode).thenReturn(true);
        },
        seed: () => const InviteCodeState(
          status: InviteCodeStatus.failure,
          error: 'Error',
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeReset()),
        expect: () => [const InviteCodeState(hasClaimedCode: true)],
      );
    });

    group('$InviteCodeState', () {
      test('isLoading returns true when status is loading', () {
        const state = InviteCodeState(status: InviteCodeStatus.loading);

        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false when status is not loading', () {
        const state = InviteCodeState();

        expect(state.isLoading, isFalse);
      });

      test('copyWith preserves existing values when no args provided', () {
        const state = InviteCodeState(
          status: InviteCodeStatus.success,
          hasClaimedCode: true,
          error: 'test',
        );

        final copied = state.copyWith();

        expect(copied.status, equals(InviteCodeStatus.success));
        expect(copied.hasClaimedCode, isTrue);
        expect(copied.error, equals('test'));
      });

      test('copyWith with clearError removes error', () {
        const state = InviteCodeState(
          status: InviteCodeStatus.failure,
          error: 'Previous error',
        );

        final cleared = state.copyWith(clearError: true);

        expect(cleared.error, isNull);
        expect(cleared.status, equals(InviteCodeStatus.failure));
      });

      test('two states with same values are equal', () {
        const state1 = InviteCodeState(
          status: InviteCodeStatus.success,
          hasClaimedCode: true,
        );
        const state2 = InviteCodeState(
          status: InviteCodeStatus.success,
          hasClaimedCode: true,
        );

        expect(state1, equals(state2));
      });

      test('two states with different values are not equal', () {
        const state1 = InviteCodeState(status: InviteCodeStatus.loading);
        const state2 = InviteCodeState(status: InviteCodeStatus.success);

        expect(state1, isNot(equals(state2)));
      });
    });

    group('$InviteCodeClaimRequested event', () {
      test('props contains code', () {
        const event = InviteCodeClaimRequested('MY-CODE');

        expect(event.props, equals(['MY-CODE']));
        expect(event.code, equals('MY-CODE'));
      });
    });

    group('$InviteCodeReset event', () {
      test('props is empty', () {
        const event = InviteCodeReset();

        expect(event.props, isEmpty);
      });
    });
  });
}
