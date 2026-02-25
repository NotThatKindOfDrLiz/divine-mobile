// ABOUTME: Tests for WaitlistScreen
// ABOUTME: Verifies email input, submit button, back button, and bottom sheets

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/waitlist/waitlist_bloc.dart';
import 'package:openvine/screens/auth/waitlist_screen.dart';
import 'package:openvine/widgets/auth_back_button.dart';

void main() {
  group(WaitlistScreen, () {
    late WaitlistBloc waitlistBloc;

    setUp(() {
      waitlistBloc = WaitlistBloc();
    });

    tearDown(() async {
      await waitlistBloc.close();
    });

    Widget createTestWidget({String? message}) {
      return BlocProvider<WaitlistBloc>.value(
        value: waitlistBloc,
        child: MaterialApp.router(
          theme: VineTheme.theme,
          routerConfig: GoRouter(
            initialLocation: WaitlistScreen.path,
            routes: [
              GoRoute(
                path: '/invite',
                builder: (_, __) => const Scaffold(body: Text('Invite Screen')),
                routes: [
                  GoRoute(
                    path: 'waitlist',
                    builder: (_, state) {
                      final args = state.extra as WaitlistScreenArgs?;
                      return WaitlistScreen(message: args?.message ?? message);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays Join the waitlist title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Join the waitlist'), findsOneWidget);
      });

      testWidgets('displays subtitle text', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('Divine will launch soon!'), findsOneWidget);
      });

      testWidgets('displays email text field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Email'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('displays Join waitlist submit button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(ElevatedButton, 'Join waitlist'),
          findsOneWidget,
        );
      });

      testWidgets('displays $AuthBackButton', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthBackButton), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('submits email to $WaitlistBloc on button tap', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter email
        await tester.enterText(find.byType(TextField), 'test@example.com');
        await tester.pump();

        // Tap submit
        await tester.tap(find.widgetWithText(ElevatedButton, 'Join waitlist'));
        await tester.pump();

        // BLoC should be in submitting state
        expect(waitlistBloc.state.isSubmitting, isTrue);
      });

      testWidgets('does not submit when email is empty', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap submit without entering email
        await tester.tap(find.widgetWithText(ElevatedButton, 'Join waitlist'));
        await tester.pump();

        // BLoC should remain in initial state
        expect(waitlistBloc.state.status, equals(WaitlistStatus.initial));
      });

      testWidgets('shows success bottom sheet after email is submitted', (
        tester,
      ) async {
        // Use a larger viewport to avoid overflow in bottom sheet
        await tester.binding.setSurfaceSize(const Size(640, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter email and submit
        await tester.enterText(find.byType(TextField), 'test@example.com');
        await tester.pump();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Join waitlist'));

        // Advance past the simulated 1-second API delay
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Success bottom sheet should appear
        expect(find.text("You're in!"), findsOneWidget);
        expect(find.text('test@example.com'), findsOneWidget);
      });
    });

    group('message bottom sheet', () {
      testWidgets(
        'shows message bottom sheet when message argument is provided',
        (tester) async {
          // Use a larger viewport to avoid overflow in bottom sheet
          await tester.binding.setSurfaceSize(const Size(640, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            createTestWidget(message: 'Account not verified'),
          );
          await tester.pumpAndSettle();

          // Message bottom sheet should appear
          expect(find.text('Account not verified'), findsOneWidget);
        },
      );
    });
  });
}
