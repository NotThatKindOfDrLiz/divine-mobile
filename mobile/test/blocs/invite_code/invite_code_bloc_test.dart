// ABOUTME: Tests for InviteCodeBloc
// ABOUTME: Verifies invite code claiming, error handling, reset, and droppable
// ABOUTME: transformer behavior

import 'dart:async';

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
  group(InviteCodeBloc, () {
    late _MockInviteCodeService mockService;
    late _MockInviteCodeRepository mockRepository;

    setUp(() {
      mockService = _MockInviteCodeService();
      mockRepository = _MockInviteCodeRepository();

      // Default: no stored code
      when(() => mockRepository.hasStoredCode).thenReturn(false);
    });

    InviteCodeBloc buildBloc() => InviteCodeBloc(
      inviteCodeService: mockService,
      repository: mockRepository,
    );

    group('initial state', () {
      test('has $InviteCodeStatus.initial and hasStoredCode false '
          'when repository has no stored code', () {
        when(() => mockRepository.hasStoredCode).thenReturn(false);

        final bloc = buildBloc();

        expect(bloc.state.status, equals(InviteCodeStatus.initial));
        expect(bloc.state.hasStoredCode, isFalse);
        expect(bloc.state.result, isNull);
        expect(bloc.state.error, isNull);

        bloc.close();
      });

      test('has $InviteCodeStatus.initial and hasStoredCode true '
          'when repository has stored code', () {
        when(() => mockRepository.hasStoredCode).thenReturn(true);

        final bloc = buildBloc();

        expect(bloc.state.status, equals(InviteCodeStatus.initial));
        expect(bloc.state.hasStoredCode, isTrue);
        expect(bloc.state.result, isNull);
        expect(bloc.state.error, isNull);

        bloc.close();
      });
    });

    group('hasStoredInviteCode', () {
      test('delegates to repository.hasStoredCode when false', () {
        when(() => mockRepository.hasStoredCode).thenReturn(false);

        final bloc = buildBloc();

        expect(bloc.hasStoredInviteCode, isFalse);
        verify(
          () => mockRepository.hasStoredCode,
        ).called(greaterThanOrEqualTo(1));

        bloc.close();
      });

      test('delegates to repository.hasStoredCode when true', () {
        when(() => mockRepository.hasStoredCode).thenReturn(true);

        final bloc = buildBloc();

        expect(bloc.hasStoredInviteCode, isTrue);
        verify(
          () => mockRepository.hasStoredCode,
        ).called(greaterThanOrEqualTo(1));

        bloc.close();
      });
    });

    group('$InviteCodeClaimRequested', () {
      const testCode = 'ABCD1234';
      const validResult = InviteCodeResult(
        valid: true,
        message: 'Code claimed successfully',
        code: 'ABCD1234',
      );
      const invalidResult = InviteCodeResult(
        valid: false,
        message: 'Code has already been used',
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'emits [loading, success] when claim returns valid result',
        setUp: () {
          when(
            () => mockService.claimCode(testCode),
          ).thenAnswer((_) async => validResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested(testCode)),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.success,
            hasStoredCode: true,
            result: validResult,
          ),
        ],
        verify: (_) {
          verify(() => mockService.claimCode(testCode)).called(1);
        },
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'emits [loading, failure] with error message '
        'when claim returns invalid result',
        setUp: () {
          when(
            () => mockService.claimCode(testCode),
          ).thenAnswer((_) async => invalidResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested(testCode)),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.failure,
            result: invalidResult,
            error: 'Code has already been used',
          ),
        ],
        verify: (_) {
          verify(() => mockService.claimCode(testCode)).called(1);
        },
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'emits [loading, failure] with exception message '
        'when service throws $InviteCodeException',
        setUp: () {
          when(() => mockService.claimCode(testCode)).thenThrow(
            const InviteCodeException('Request timed out. Please try again.'),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested(testCode)),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.failure,
            error: 'Request timed out. Please try again.',
          ),
        ],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'emits [loading, failure] with generic error message '
        'when service throws unexpected exception',
        setUp: () {
          when(
            () => mockService.claimCode(testCode),
          ).thenThrow(Exception('Something unexpected'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested(testCode)),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.failure,
            error: 'An unexpected error occurred. Please try again.',
          ),
        ],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'clears previous error when new claim is requested',
        setUp: () {
          when(
            () => mockService.claimCode(testCode),
          ).thenAnswer((_) async => validResult);
        },
        seed: () => const InviteCodeState(
          status: InviteCodeStatus.failure,
          error: 'Previous error',
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeClaimRequested(testCode)),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.success,
            hasStoredCode: true,
            result: validResult,
          ),
        ],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'drops second event while first is still processing '
        '(droppable transformer)',
        setUp: () {
          final completer = Completer<InviteCodeResult>();

          // First call: hangs until completer completes
          // Second call: would return immediately (if not dropped)
          var callCount = 0;
          when(() => mockService.claimCode(any())).thenAnswer((_) {
            callCount++;
            if (callCount == 1) {
              return completer.future;
            }
            return Future.value(
              const InviteCodeResult(
                valid: true,
                message: 'Second call result',
              ),
            );
          });

          // Complete the first call after a brief delay so we can
          // verify the second was dropped
          Future<void>.delayed(
            const Duration(milliseconds: 50),
            () => completer.complete(validResult),
          );
        },
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const InviteCodeClaimRequested(testCode))
            ..add(const InviteCodeClaimRequested('SECOND01'));
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const InviteCodeState(status: InviteCodeStatus.loading),
          const InviteCodeState(
            status: InviteCodeStatus.success,
            hasStoredCode: true,
            result: validResult,
          ),
        ],
        verify: (_) {
          // Only the first call should have been made;
          // the second event should have been dropped.
          verify(() => mockService.claimCode(testCode)).called(1);
          verifyNever(() => mockService.claimCode('SECOND01'));
        },
      );
    });

    group('$InviteCodeReset', () {
      blocTest<InviteCodeBloc, InviteCodeState>(
        'resets state to initial with hasStoredCode from repository '
        'when repository has no stored code',
        setUp: () {
          when(() => mockRepository.hasStoredCode).thenReturn(false);
        },
        seed: () => const InviteCodeState(
          status: InviteCodeStatus.success,
          hasStoredCode: true,
          result: InviteCodeResult(valid: true, code: 'ABCD1234'),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeReset()),
        expect: () => [const InviteCodeState(hasStoredCode: false)],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'resets state to initial with hasStoredCode true '
        'when repository has stored code',
        setUp: () {
          // Override the default for this test
          when(() => mockRepository.hasStoredCode).thenReturn(true);
        },
        seed: () => const InviteCodeState(
          status: InviteCodeStatus.failure,
          error: 'Some error',
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeReset()),
        expect: () => [const InviteCodeState(hasStoredCode: true)],
      );

      blocTest<InviteCodeBloc, InviteCodeState>(
        'clears error and result when resetting from failure state',
        seed: () => const InviteCodeState(
          status: InviteCodeStatus.failure,
          error: 'Code has already been used',
          result: InviteCodeResult(
            valid: false,
            message: 'Code has already been used',
          ),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteCodeReset()),
        expect: () => [const InviteCodeState()],
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

      test('isSuccess returns true when status is success', () {
        const state = InviteCodeState(status: InviteCodeStatus.success);
        expect(state.isSuccess, isTrue);
      });

      test('isFailure returns true when status is failure', () {
        const state = InviteCodeState(status: InviteCodeStatus.failure);
        expect(state.isFailure, isTrue);
      });

      test('copyWith preserves existing values when no arguments given', () {
        const state = InviteCodeState(
          status: InviteCodeStatus.success,
          hasStoredCode: true,
          error: 'test',
        );
        final copied = state.copyWith();
        expect(copied, equals(state));
      });

      test('copyWith clearError sets error to null', () {
        const state = InviteCodeState(
          status: InviteCodeStatus.failure,
          error: 'some error',
        );
        final cleared = state.copyWith(clearError: true);
        expect(cleared.error, isNull);
        expect(cleared.status, equals(InviteCodeStatus.failure));
      });

      test('supports equality', () {
        const stateA = InviteCodeState();
        const stateB = InviteCodeState();
        expect(stateA, equals(stateB));
      });

      test('different states are not equal', () {
        const stateA = InviteCodeState();
        const stateB = InviteCodeState(status: InviteCodeStatus.loading);
        expect(stateA, isNot(equals(stateB)));
      });
    });

    group('$InviteCodeEvent', () {
      test('$InviteCodeClaimRequested supports equality', () {
        expect(
          const InviteCodeClaimRequested('ABCD1234'),
          equals(const InviteCodeClaimRequested('ABCD1234')),
        );
      });

      test('$InviteCodeClaimRequested with different codes are not equal', () {
        expect(
          const InviteCodeClaimRequested('ABCD1234'),
          isNot(equals(const InviteCodeClaimRequested('WXYZ5678'))),
        );
      });

      test('$InviteCodeReset supports equality', () {
        expect(const InviteCodeReset(), equals(const InviteCodeReset()));
      });
    });
  });
}
