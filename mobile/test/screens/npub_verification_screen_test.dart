// ABOUTME: Tests for NpubVerificationScreen
// ABOUTME: Verifies loading state, error handling, and verification flow

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/models/npub_verification_result.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/screens/auth/invite_choice_screen.dart';
import 'package:openvine/screens/auth/waitlist_screen.dart';
import 'package:openvine/screens/npub_verification_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/npub_verification_service.dart';
import 'package:openvine/widgets/auth_back_button.dart';

import '../helpers/test_provider_overrides.dart';

class _MockNpubVerificationService extends Mock
    implements NpubVerificationService {}

class _MockNpubVerificationRepository extends Mock
    implements NpubVerificationRepository {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(NpubVerificationScreen, () {
    late _MockNpubVerificationService mockService;
    late _MockNpubVerificationRepository mockRepository;
    late NpubVerificationBloc npubVerificationBloc;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockService = _MockNpubVerificationService();
      mockRepository = _MockNpubVerificationRepository();
      mockAuthService = _MockAuthService();

      when(() => mockRepository.isVerified(any())).thenReturn(false);
      when(() => mockAuthService.currentNpub).thenReturn('npub1testkey');
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      npubVerificationBloc = NpubVerificationBloc(
        verificationService: mockService,
        repository: mockRepository,
      );
    });

    tearDown(() async {
      await npubVerificationBloc.close();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
        ],
        child: BlocProvider<NpubVerificationBloc>.value(
          value: npubVerificationBloc,
          child: MaterialApp.router(
            theme: VineTheme.theme,
            routerConfig: GoRouter(
              initialLocation: NpubVerificationScreen.path,
              routes: [
                GoRoute(
                  path: NpubVerificationScreen.path,
                  builder: (_, __) => const NpubVerificationScreen(),
                ),
                GoRoute(
                  path: InviteChoiceScreen.path,
                  builder: (_, __) =>
                      const Scaffold(body: Text('Invite Screen')),
                ),
                GoRoute(
                  path: WaitlistScreen.path,
                  builder: (_, state) =>
                      const Scaffold(body: Text('Waitlist Screen')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays verifying state with loading indicator', (
        tester,
      ) async {
        // Make verifyNpub hang so we stay in verifying state
        when(() => mockService.verifyNpub(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return const NpubVerificationResult(valid: true);
        });

        await tester.pumpWidget(createTestWidget());
        // Wait for post-frame callback to fire
        await tester.pump();
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Verifying your account...'), findsOneWidget);
      });

      testWidgets('displays $AuthBackButton', (tester) async {
        when(() => mockService.verifyNpub(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return const NpubVerificationResult(valid: true);
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pump();

        expect(find.byType(AuthBackButton), findsOneWidget);
      });
    });

    group('verification flow', () {
      testWidgets('calls verifyNpub on the service', (tester) async {
        when(() => mockService.verifyNpub(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return const NpubVerificationResult(valid: true);
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pump();

        verify(() => mockService.verifyNpub('npub1testkey')).called(1);
      });

      testWidgets('shows error state with retry button on server failure', (
        tester,
      ) async {
        when(
          () => mockService.verifyNpub(any()),
        ).thenThrow(const NpubVerificationException('Server error'));

        await tester.pumpWidget(createTestWidget());
        // Wait for post-frame callback + bloc processing
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.text('Verification Failed'), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, 'Try Again'),
          findsOneWidget,
        );
      });

      testWidgets('retry button resubmits verification', (tester) async {
        var callCount = 0;
        when(() => mockService.verifyNpub(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const NpubVerificationException('Server error');
          }
          // Second call hangs
          await Future<void>.delayed(const Duration(seconds: 30));
          return const NpubVerificationResult(valid: true);
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Should show error with retry
        expect(find.text('Verification Failed'), findsOneWidget);

        // Tap retry
        await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
        await tester.pump();
        await tester.pump();

        // Should show loading again
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(callCount, equals(2));
      });
    });

    group('cancel', () {
      testWidgets(
        'tapping back button signs out and navigates to invite screen',
        (tester) async {
          when(() => mockService.verifyNpub(any())).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 30));
            return const NpubVerificationResult(valid: true);
          });

          await tester.pumpWidget(createTestWidget());
          await tester.pump();
          await tester.pump();

          // Tap back button
          await tester.tap(find.byType(AuthBackButton));
          await tester.pumpAndSettle();

          verify(() => mockAuthService.signOut()).called(1);
          expect(find.text('Invite Screen'), findsOneWidget);
        },
      );
    });
  });
}
