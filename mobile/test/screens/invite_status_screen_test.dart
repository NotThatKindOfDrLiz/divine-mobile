// ABOUTME: Tests for InviteStatusScreen
// ABOUTME: Verifies loading state, success display, error handling, and retry

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_bloc.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/screens/invite_status_screen.dart';

class _MockInviteStatusBloc
    extends MockBloc<InviteStatusEvent, InviteStatusState>
    implements InviteStatusBloc {}

void main() {
  group(InviteStatusView, () {
    late _MockInviteStatusBloc mockBloc;

    setUp(() {
      mockBloc = _MockInviteStatusBloc();
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget createTestWidget() {
      return MaterialApp(
        theme: VineTheme.theme,
        home: BlocProvider<InviteStatusBloc>.value(
          value: mockBloc,
          child: const InviteStatusView(),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays loading indicator while fetching', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(status: InviteStatusStatus.loading),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('displays loading indicator for initial state', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(const InviteStatusState());

        await tester.pumpWidget(createTestWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('displays Invites title in app bar', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(status: InviteStatusStatus.loading),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Invites'), findsOneWidget);
      });
    });

    group('success', () {
      testWidgets('displays Active status when invite is valid', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusStatus.success,
            result: InviteCodeResult(valid: true),
          ),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Invite Status'), findsOneWidget);
      });

      testWidgets('displays Inactive status when invite is invalid', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusStatus.success,
            result: InviteCodeResult(valid: false),
          ),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Inactive'), findsOneWidget);
      });

      testWidgets('displays invite code when present', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusStatus.success,
            result: InviteCodeResult(valid: true, code: 'ABCD1234'),
          ),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Invite Code'), findsOneWidget);
        expect(find.text('ABCD1234'), findsOneWidget);
      });

      testWidgets('displays claimed date when present', (tester) async {
        when(() => mockBloc.state).thenReturn(
          InviteStatusState(
            status: InviteStatusStatus.success,
            result: InviteCodeResult(
              valid: true,
              claimedAt: DateTime(2025, 3, 15),
            ),
          ),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Claimed'), findsOneWidget);
        expect(find.text('March 15, 2025'), findsOneWidget);
      });

      testWidgets('displays message when present', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusStatus.success,
            result: InviteCodeResult(valid: true, message: 'Invite is active'),
          ),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Details'), findsOneWidget);
        expect(find.text('Invite is active'), findsOneWidget);
      });

      testWidgets('does not display code card when code is null', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusStatus.success,
            result: InviteCodeResult(valid: true),
          ),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Invite Code'), findsNothing);
      });
    });

    group('error', () {
      testWidgets('displays error message on failure', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusStatus.failure,
            error: 'Server unavailable',
          ),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Server unavailable'), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, 'Try Again'),
          findsOneWidget,
        );
      });

      testWidgets('displays generic error when error message is null', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(status: InviteStatusStatus.failure),
        );

        await tester.pumpWidget(createTestWidget());

        expect(find.text('Failed to load invite status'), findsOneWidget);
      });

      testWidgets('retry button adds $InviteStatusRequested event', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusStatus.failure,
            error: 'Server error',
          ),
        );

        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));

        verify(() => mockBloc.add(const InviteStatusRequested())).called(1);
      });
    });
  });
}
