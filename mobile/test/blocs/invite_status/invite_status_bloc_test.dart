// ABOUTME: Unit tests for InviteStatusBloc
// ABOUTME: Tests fetch success, failure, and retry behavior

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_bloc.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/services/invite_code_service.dart';

class _MockInviteCodeService extends Mock implements InviteCodeService {}

void main() {
  group(InviteStatusBloc, () {
    late _MockInviteCodeService mockService;

    setUp(() {
      mockService = _MockInviteCodeService();
    });

    InviteStatusBloc buildBloc() =>
        InviteStatusBloc(inviteCodeService: mockService);

    group('initial state', () {
      test('has correct initial state', () {
        final bloc = buildBloc();
        expect(bloc.state.status, equals(InviteStatusStatus.initial));
        expect(bloc.state.result, isNull);
        expect(bloc.state.error, isNull);
        bloc.close();
      });
    });

    group(InviteStatusRequested, () {
      const validResult = InviteCodeResult(
        valid: true,
        code: 'ABCD1234',
        message: 'Invite is active',
      );

      const invalidResult = InviteCodeResult(valid: false);

      blocTest<InviteStatusBloc, InviteStatusState>(
        'emits [loading, success] when getInviteStatus succeeds '
        'with valid result',
        setUp: () {
          when(
            () => mockService.getInviteStatus(),
          ).thenAnswer((_) async => validResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteStatusRequested()),
        expect: () => const [
          InviteStatusState(status: InviteStatusStatus.loading),
          InviteStatusState(
            status: InviteStatusStatus.success,
            result: validResult,
          ),
        ],
      );

      blocTest<InviteStatusBloc, InviteStatusState>(
        'emits [loading, success] when getInviteStatus succeeds '
        'with invalid result',
        setUp: () {
          when(
            () => mockService.getInviteStatus(),
          ).thenAnswer((_) async => invalidResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteStatusRequested()),
        expect: () => const [
          InviteStatusState(status: InviteStatusStatus.loading),
          InviteStatusState(
            status: InviteStatusStatus.success,
            result: invalidResult,
          ),
        ],
      );

      blocTest<InviteStatusBloc, InviteStatusState>(
        'emits [loading, failure] with message on $InviteCodeException',
        setUp: () {
          when(
            () => mockService.getInviteStatus(),
          ).thenThrow(const InviteCodeException('Server unavailable'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteStatusRequested()),
        expect: () => const [
          InviteStatusState(status: InviteStatusStatus.loading),
          InviteStatusState(
            status: InviteStatusStatus.failure,
            error: 'Server unavailable',
          ),
        ],
      );

      blocTest<InviteStatusBloc, InviteStatusState>(
        'emits [loading, failure] with generic message on unexpected error',
        setUp: () {
          when(
            () => mockService.getInviteStatus(),
          ).thenThrow(Exception('unexpected'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteStatusRequested()),
        expect: () => const [
          InviteStatusState(status: InviteStatusStatus.loading),
          InviteStatusState(
            status: InviteStatusStatus.failure,
            error: 'Failed to load invite status',
          ),
        ],
      );

      blocTest<InviteStatusBloc, InviteStatusState>(
        'retry succeeds after initial failure',
        setUp: () {
          var callCount = 0;
          when(() => mockService.getInviteStatus()).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              throw const InviteCodeException('Server error');
            }
            return validResult;
          });
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const InviteStatusRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const InviteStatusRequested());
        },
        expect: () => const [
          InviteStatusState(status: InviteStatusStatus.loading),
          InviteStatusState(
            status: InviteStatusStatus.failure,
            error: 'Server error',
          ),
          InviteStatusState(status: InviteStatusStatus.loading),
          InviteStatusState(
            status: InviteStatusStatus.success,
            result: validResult,
          ),
        ],
      );

      blocTest<InviteStatusBloc, InviteStatusState>(
        'includes result with claimedAt',
        setUp: () {
          when(() => mockService.getInviteStatus()).thenAnswer(
            (_) async =>
                InviteCodeResult(valid: true, claimedAt: DateTime(2025, 3, 15)),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const InviteStatusRequested()),
        expect: () => [
          const InviteStatusState(status: InviteStatusStatus.loading),
          InviteStatusState(
            status: InviteStatusStatus.success,
            result: InviteCodeResult(
              valid: true,
              claimedAt: DateTime(2025, 3, 15),
            ),
          ),
        ],
      );
    });
  });
}
