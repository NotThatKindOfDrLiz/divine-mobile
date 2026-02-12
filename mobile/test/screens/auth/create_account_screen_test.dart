// ABOUTME: Tests for CreateAccountScreen
// ABOUTME: Verifies form rendering, confirm password validation,
// ABOUTME: submit interaction, and skip button behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/widgets/auth_back_button.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

void main() {
  late _MockKeycastOAuth mockOAuth;
  late _MockAuthService mockAuthService;
  late _MockPendingVerificationService mockPendingVerification;

  setUp(() {
    mockOAuth = _MockKeycastOAuth();
    mockAuthService = _MockAuthService();
    mockPendingVerification = _MockPendingVerificationService();

    when(() => mockAuthService.signInAutomatically()).thenAnswer((_) async {});
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        ...getStandardTestOverrides(mockAuthService: mockAuthService),
        oauthClientProvider.overrideWithValue(mockOAuth),
        pendingVerificationServiceProvider.overrideWithValue(
          mockPendingVerification,
        ),
      ],
      child: MaterialApp(
        theme: VineTheme.theme,
        home: const CreateAccountScreen(),
      ),
    );
  }

  group(CreateAccountScreen, () {
    group('renders', () {
      testWidgets('displays title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == 'Create account' &&
                widget.style?.fontSize == 28,
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays $AuthBackButton', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthBackButton), findsOneWidget);
      });

      testWidgets('displays email field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      });

      testWidgets('displays password field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      });

      testWidgets('displays confirm password field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextField, 'Confirm password'),
          findsOneWidget,
        );
      });

      testWidgets('displays create account button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(ElevatedButton, 'Create account'),
          findsOneWidget,
        );
      });

      testWidgets('displays skip button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextButton, 'Skip for now'), findsOneWidget);
      });

      testWidgets('displays dog sticker', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName.contains('samoyed_dog'),
          ),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('shows error when passwords do not match', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter password
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'password123',
        );

        // Enter different confirm password
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm password'),
          'different456',
        );

        // Tap create account
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text('Passwords do not match'), findsOneWidget);
      });

      testWidgets('clears confirm password error on typing', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Trigger mismatch error
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'password123',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm password'),
          'different456',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
        await tester.pumpAndSettle();

        expect(find.text('Passwords do not match'), findsOneWidget);

        // Type in confirm password field to clear error
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm password'),
          'a',
        );
        await tester.pumpAndSettle();

        expect(find.text('Passwords do not match'), findsNothing);
      });

      testWidgets('tapping skip calls signInAutomatically', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Skip for now'));
        await tester.pump();

        verify(() => mockAuthService.signInAutomatically()).called(1);
      });

      testWidgets('calls submit when passwords match', (tester) async {
        // Stub headlessRegister so submit proceeds
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessRegisterResult(
              success: true,
              pubkey: 'test-pubkey',
              verificationRequired: false,
              email: 'test@example.com',
            ),
            'test-verifier',
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter email
        await tester.enterText(
          find.widgetWithText(TextField, 'Email'),
          'test@example.com',
        );

        // Enter matching passwords
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'SecurePass123!',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm password'),
          'SecurePass123!',
        );

        // Tap create account
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify the cubit called headlessRegister (via submit)
        verify(
          () => mockOAuth.headlessRegister(
            email: 'test@example.com',
            password: 'SecurePass123!',
            scope: 'policy:full',
          ),
        ).called(1);
      });

      testWidgets('does not submit when passwords do not match', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter email
        await tester.enterText(
          find.widgetWithText(TextField, 'Email'),
          'test@example.com',
        );

        // Enter mismatched passwords
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'SecurePass123!',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm password'),
          'DifferentPass456!',
        );

        // Tap create account
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
        await tester.pump();

        // Verify headlessRegister was NOT called
        verifyNever(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        );
      });
    });
  });
}
