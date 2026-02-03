// ABOUTME: Widget tests for InviteCodeScreen UI and functionality
// ABOUTME: Tests form validation, submission states, error display, and deep link auto-fill

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/providers/invite_code_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/screens/invite_code_screen.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('InviteCodeScreen', () {
    late SharedPreferences mockPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();
    });

    Widget createTestWidget({
      InviteCodeService? mockService,
      String? pendingCode,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          if (mockService != null)
            inviteCodeServiceProvider.overrideWithValue(mockService),
          if (pendingCode != null)
            pendingInviteCodeProvider.overrideWithValue(pendingCode),
        ],
        child: const MaterialApp(home: InviteCodeScreen()),
      );
    }

    InviteCodeService createMockService({required http.Client client}) {
      final repository = InviteCodeRepository(mockPrefs);
      return InviteCodeService(
        client: client,
        repository: repository,
        prefs: mockPrefs,
      );
    }

    group('UI rendering', () {
      testWidgets('displays logo and title', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Enter Invite Code'), findsOneWidget);
        expect(
          find.text(
            'Divine is currently invite-only.\n'
            'Enter your 8-character invite code to continue.',
          ),
          findsOneWidget,
        );
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

      testWidgets('displays help text', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(
          find.text(
            "Don't have an invite code?\n"
            'Ask a friend or wait for public access.',
          ),
          findsOneWidget,
        );
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
      testWidgets('shows loading indicator while submitting', (tester) async {
        final mockClient = MockClient((request) async {
          // Simulate slow response that never completes during test
          await Future.delayed(const Duration(seconds: 10));
          return http.Response(
            jsonEncode({'valid': true, 'code': 'ABCD1234'}),
            200,
          );
        });

        final service = createMockService(client: mockClient);

        await tester.pumpWidget(createTestWidget(mockService: service));

        await tester.enterText(find.byType(TextField), 'ABCD1234');
        await tester.tap(find.text('Continue'));
        // Pump once to trigger state change to loading
        await tester.pump();

        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Continue'), findsNothing);
      });

      testWidgets('shows error message when code is invalid', (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': false, 'message': 'Invalid invite code'}),
            200,
          );
        });

        final service = createMockService(client: mockClient);

        await tester.pumpWidget(createTestWidget(mockService: service));

        await tester.enterText(find.byType(TextField), 'BADCODE1');
        await tester.tap(find.text('Continue'));

        // Use runAsync to complete the async HTTP operation
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        expect(find.text('Invalid invite code'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('shows error message on server error', (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = createMockService(client: mockClient);

        await tester.pumpWidget(createTestWidget(mockService: service));

        await tester.enterText(find.byType(TextField), 'ABCD1234');
        await tester.tap(find.text('Continue'));

        // Use runAsync to complete the async HTTP operation
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        // Should show error message
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('button is disabled while submitting', (tester) async {
        final mockClient = MockClient((request) async {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response(
            jsonEncode({'valid': true, 'code': 'ABCD1234'}),
            200,
          );
        });

        final service = createMockService(client: mockClient);

        await tester.pumpWidget(createTestWidget(mockService: service));

        await tester.enterText(find.byType(TextField), 'ABCD1234');
        await tester.tap(find.text('Continue'));
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('input field is disabled while submitting', (tester) async {
        final mockClient = MockClient((request) async {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response(
            jsonEncode({'valid': true, 'code': 'ABCD1234'}),
            200,
          );
        });

        final service = createMockService(client: mockClient);

        await tester.pumpWidget(createTestWidget(mockService: service));

        await tester.enterText(find.byType(TextField), 'ABCD1234');
        await tester.tap(find.text('Continue'));
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);
      });
    });

    group('keyboard submission', () {
      testWidgets('submits on keyboard done action', (tester) async {
        final mockClient = MockClient((request) async {
          await Future.delayed(const Duration(seconds: 10));
          return http.Response(
            jsonEncode({'valid': true, 'code': 'ABCD1234'}),
            200,
          );
        });

        final service = createMockService(client: mockClient);

        await tester.pumpWidget(createTestWidget(mockService: service));

        await tester.enterText(find.byType(TextField), 'ABCD1234');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Should start loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('error display', () {
      testWidgets('error message persists until next submission', (
        tester,
      ) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': false, 'message': 'Invalid code'}),
            200,
          );
        });

        final service = createMockService(client: mockClient);

        await tester.pumpWidget(createTestWidget(mockService: service));

        // Submit invalid code
        await tester.enterText(find.byType(TextField), 'BADCODE1');
        await tester.tap(find.text('Continue'));

        // Use runAsync to complete the async HTTP operation
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        expect(find.text('Invalid code'), findsOneWidget);

        // Clear and enter new code - error persists until next submission
        await tester.enterText(find.byType(TextField), 'NEWCODE1');
        await tester.pump();

        // Error still visible until next submit
        expect(find.text('Invalid code'), findsOneWidget);
      });

      testWidgets('shows custom error message from API', (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'valid': false,
              'message': 'This code has already been claimed',
            }),
            200,
          );
        });

        final service = createMockService(client: mockClient);

        await tester.pumpWidget(createTestWidget(mockService: service));

        await tester.enterText(find.byType(TextField), 'USED1234');
        await tester.tap(find.text('Continue'));

        // Use runAsync to complete the async HTTP operation
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        expect(find.text('This code has already been claimed'), findsOneWidget);
      });
    });
  });
}
