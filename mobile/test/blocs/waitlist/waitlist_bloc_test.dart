// ABOUTME: Tests for WaitlistBloc
// ABOUTME: Verifies email submission, failure handling, droppable
// ABOUTME: transformer, and reset behavior

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/waitlist/waitlist_bloc.dart';

void main() {
  group(WaitlistBloc, () {
    WaitlistBloc buildBloc() => WaitlistBloc();

    group('initial state', () {
      test('is $WaitlistState with initial status', () {
        final bloc = buildBloc();
        expect(bloc.state, equals(const WaitlistState()));
        expect(bloc.state.status, equals(WaitlistStatus.initial));
        expect(bloc.state.submittedEmail, isNull);
        expect(bloc.state.error, isNull);
        expect(bloc.state.isSubmitting, isFalse);
        expect(bloc.state.isSuccess, isFalse);
        expect(bloc.state.isFailure, isFalse);
        bloc.close();
      });
    });

    group('$WaitlistEmailSubmitted', () {
      const testEmail = 'test@example.com';

      blocTest<WaitlistBloc, WaitlistState>(
        'emits [submitting, success] when email submission succeeds',
        build: buildBloc,
        act: (bloc) => bloc.add(const WaitlistEmailSubmitted(testEmail)),
        wait: const Duration(seconds: 2),
        expect: () => [
          const WaitlistState(status: WaitlistStatus.submitting),
          const WaitlistState(
            status: WaitlistStatus.success,
            submittedEmail: testEmail,
          ),
        ],
      );

      blocTest<WaitlistBloc, WaitlistState>(
        'clears previous error when submitting',
        seed: () => const WaitlistState(
          status: WaitlistStatus.failure,
          error: 'Previous error',
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const WaitlistEmailSubmitted(testEmail)),
        wait: const Duration(seconds: 2),
        expect: () => [
          const WaitlistState(status: WaitlistStatus.submitting),
          const WaitlistState(
            status: WaitlistStatus.success,
            submittedEmail: testEmail,
          ),
        ],
      );

      blocTest<WaitlistBloc, WaitlistState>(
        'drops subsequent events while processing '
        '(droppable transformer)',
        build: buildBloc,
        act: (bloc) {
          bloc
            ..add(const WaitlistEmailSubmitted('first@example.com'))
            ..add(const WaitlistEmailSubmitted('second@example.com'));
        },
        wait: const Duration(seconds: 2),
        expect: () => [
          const WaitlistState(status: WaitlistStatus.submitting),
          const WaitlistState(
            status: WaitlistStatus.success,
            submittedEmail: 'first@example.com',
          ),
        ],
      );
    });

    group('$WaitlistReset', () {
      blocTest<WaitlistBloc, WaitlistState>(
        'resets state to initial from success',
        seed: () => const WaitlistState(
          status: WaitlistStatus.success,
          submittedEmail: 'test@example.com',
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const WaitlistReset()),
        expect: () => [const WaitlistState()],
      );

      blocTest<WaitlistBloc, WaitlistState>(
        'resets state to initial from failure',
        seed: () => const WaitlistState(
          status: WaitlistStatus.failure,
          error: 'Failed to join waitlist. Please try again.',
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const WaitlistReset()),
        expect: () => [const WaitlistState()],
      );

      blocTest<WaitlistBloc, WaitlistState>(
        'emits initial state even when already initial '
        '(handler always emits)',
        build: buildBloc,
        act: (bloc) => bloc.add(const WaitlistReset()),
        expect: () => [const WaitlistState()],
      );
    });
  });

  group('$WaitlistState', () {
    test('isSubmitting returns true when status is submitting', () {
      const state = WaitlistState(status: WaitlistStatus.submitting);
      expect(state.isSubmitting, isTrue);
    });

    test('isSuccess returns true when status is success', () {
      const state = WaitlistState(status: WaitlistStatus.success);
      expect(state.isSuccess, isTrue);
    });

    test('isFailure returns true when status is failure', () {
      const state = WaitlistState(status: WaitlistStatus.failure);
      expect(state.isFailure, isTrue);
    });

    test('copyWith returns new state with updated status', () {
      const state = WaitlistState();
      final updated = state.copyWith(status: WaitlistStatus.submitting);
      expect(updated.status, equals(WaitlistStatus.submitting));
      expect(updated.submittedEmail, isNull);
      expect(updated.error, isNull);
    });

    test('copyWith preserves existing values when not overridden', () {
      const state = WaitlistState(
        status: WaitlistStatus.success,
        submittedEmail: 'test@example.com',
      );
      final updated = state.copyWith(status: WaitlistStatus.submitting);
      expect(updated.status, equals(WaitlistStatus.submitting));
      expect(updated.submittedEmail, equals('test@example.com'));
    });

    test('copyWith clearError removes error', () {
      const state = WaitlistState(
        status: WaitlistStatus.failure,
        error: 'some error',
      );
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith clearError false preserves error', () {
      const state = WaitlistState(
        status: WaitlistStatus.failure,
        error: 'some error',
      );
      final updated = state.copyWith(status: WaitlistStatus.submitting);
      expect(updated.error, equals('some error'));
    });

    test('supports equality comparison', () {
      expect(const WaitlistState(), equals(const WaitlistState()));
    });

    test('states with different status are not equal', () {
      expect(
        const WaitlistState(),
        isNot(equals(const WaitlistState(status: WaitlistStatus.submitting))),
      );
    });

    test('states with different submittedEmail are not equal', () {
      expect(
        const WaitlistState(
          status: WaitlistStatus.success,
          submittedEmail: 'a@example.com',
        ),
        isNot(
          equals(
            const WaitlistState(
              status: WaitlistStatus.success,
              submittedEmail: 'b@example.com',
            ),
          ),
        ),
      );
    });

    test('states with different error are not equal', () {
      expect(
        const WaitlistState(status: WaitlistStatus.failure, error: 'error 1'),
        isNot(
          equals(
            const WaitlistState(
              status: WaitlistStatus.failure,
              error: 'error 2',
            ),
          ),
        ),
      );
    });
  });

  group('$WaitlistEvent', () {
    test('$WaitlistEmailSubmitted instances with same email are equal', () {
      expect(
        const WaitlistEmailSubmitted('test@example.com'),
        equals(const WaitlistEmailSubmitted('test@example.com')),
      );
    });

    test('$WaitlistEmailSubmitted instances with different email '
        'are not equal', () {
      expect(
        const WaitlistEmailSubmitted('a@example.com'),
        isNot(equals(const WaitlistEmailSubmitted('b@example.com'))),
      );
    });

    test('$WaitlistReset instances are equal', () {
      expect(const WaitlistReset(), equals(const WaitlistReset()));
    });
  });
}
