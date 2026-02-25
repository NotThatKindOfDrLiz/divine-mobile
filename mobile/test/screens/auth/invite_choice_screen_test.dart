// ABOUTME: Tests for InviteChoiceScreen
// ABOUTME: Verifies rendering of buttons and navigation on tap

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/screens/auth/invite_choice_screen.dart';
import 'package:openvine/screens/auth/invite_code_entry_screen.dart';
import 'package:openvine/screens/auth/waitlist_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/npub_verification_service.dart';

class _MockNpubVerificationService extends Mock
    implements NpubVerificationService {}

class _MockNpubVerificationRepository extends Mock
    implements NpubVerificationRepository {}

void main() {
  group(InviteChoiceScreen, () {
    late NpubVerificationBloc npubVerificationBloc;

    setUp(() {
      final mockService = _MockNpubVerificationService();
      final mockRepository = _MockNpubVerificationRepository();
      when(() => mockRepository.isVerified(any())).thenReturn(false);

      npubVerificationBloc = NpubVerificationBloc(
        verificationService: mockService,
        repository: mockRepository,
      );
    });

    tearDown(() async {
      await npubVerificationBloc.close();
    });

    Widget createTestWidget() {
      return BlocProvider<NpubVerificationBloc>.value(
        value: npubVerificationBloc,
        child: MaterialApp.router(
          theme: VineTheme.theme,
          routerConfig: GoRouter(
            initialLocation: InviteChoiceScreen.path,
            routes: [
              GoRoute(
                path: InviteChoiceScreen.path,
                builder: (_, __) => const InviteChoiceScreen(),
              ),
              GoRoute(
                path: InviteCodeEntryScreen.path,
                builder: (_, __) =>
                    const Scaffold(body: Text('Enter Code Screen')),
              ),
              GoRoute(
                path: WaitlistScreen.path,
                builder: (_, __) =>
                    const Scaffold(body: Text('Waitlist Screen')),
              ),
              GoRoute(
                path: WelcomeScreen.path,
                builder: (_, __) =>
                    const Scaffold(body: Text('Welcome Screen')),
              ),
            ],
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays Enter invite code button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(
          find.widgetWithText(ElevatedButton, 'Enter invite code'),
          findsOneWidget,
        );
      });

      testWidgets('displays Join the waitlist button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(
          find.widgetWithText(OutlinedButton, 'Join the waitlist'),
          findsOneWidget,
        );
      });

      testWidgets('displays Sign in text link', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Sign in link is inside a RichText with TextSpans
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('Sign in'),
          ),
          findsOneWidget,
        );
      });
    });

    group('navigation', () {
      testWidgets(
        'navigates to $InviteCodeEntryScreen on Enter invite code tap',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pump();

          await tester.tap(
            find.widgetWithText(ElevatedButton, 'Enter invite code'),
          );
          await tester.pumpAndSettle();

          expect(find.text('Enter Code Screen'), findsOneWidget);
        },
      );

      testWidgets('navigates to $WaitlistScreen on Join the waitlist tap', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Join the waitlist'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Waitlist Screen'), findsOneWidget);
      });

      testWidgets(
        'navigates to $WelcomeScreen and sets skip invite flag on Sign in tap',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pump();

          // Sign in is a TextSpan inside RichText with TapGestureRecognizer
          final richTextFinder = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('Sign in'),
          );
          await tester.tap(richTextFinder);
          await tester.pumpAndSettle();

          expect(find.text('Welcome Screen'), findsOneWidget);
          expect(npubVerificationBloc.skipInviteRequested, isTrue);
        },
      );
    });
  });
}
