// ABOUTME: Widget tests for InviteCodeEntryScreen UI and functionality
// ABOUTME: Tests form validation and submission states

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_code/invite_code_bloc.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/invite_code_entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockInviteCodeBloc extends MockBloc<InviteCodeEvent, InviteCodeState>
    implements InviteCodeBloc {}

void main() {
  group('InviteCodeEntryScreen', () {
    late SharedPreferences mockPrefs;
    late MockInviteCodeBloc mockBloc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();
      mockBloc = MockInviteCodeBloc();

      // Default state
      when(() => mockBloc.state).thenReturn(const InviteCodeState());
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget createTestWidget({InviteCodeBloc? bloc}) {
      final effectiveBloc = bloc ?? mockBloc;

      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        child: MaterialApp(
          home: BlocProvider<InviteCodeBloc>.value(
            value: effectiveBloc,
            child: const InviteCodeEntryScreen(),
          ),
        ),
      );
    }

    group('UI rendering', () {
      testWidgets('displays title', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Enter Invite Code'), findsOneWidget);
      });

      testWidgets('displays input field with hint', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('ABCD1234'), findsOneWidget); // Hint text
      });

      testWidgets('displays continue button', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Continue'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('input validation', () {
      testWidgets('shows error when submitting empty code', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(find.text('Please enter an invite code'), findsOneWidget);
      });

      testWidgets('shows error when code is too short', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.enterText(find.byType(TextField), 'ABC');
        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(find.text('Invite code must be 8 characters'), findsOneWidget);
      });

      testWidgets('converts input to uppercase', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.enterText(find.byType(TextField), 'abcd1234');
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals('ABCD1234'));
      });

      testWidgets('filters non-alphanumeric characters', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.enterText(find.byType(TextField), 'AB-CD@12!34');
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        // Only alphanumeric should remain
        expect(textField.controller?.text, equals('ABCD1234'));
      });

      testWidgets('limits input to 8 characters', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.enterText(find.byType(TextField), 'ABCD12345678');
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text.length, lessThanOrEqualTo(8));
      });
    });

    group('submission', () {
      testWidgets('dispatches InviteCodeClaimRequested on valid submit', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        await tester.enterText(find.byType(TextField), 'ABCD1234');
        await tester.tap(find.text('Continue'));
        await tester.pump();

        verify(
          () => mockBloc.add(const InviteCodeClaimRequested('ABCD1234')),
        ).called(1);
      });
    });

    group('keyboard submission', () {
      testWidgets('submits on keyboard done action', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.enterText(find.byType(TextField), 'ABCD1234');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        verify(
          () => mockBloc.add(const InviteCodeClaimRequested('ABCD1234')),
        ).called(1);
      });
    });
  });
}
