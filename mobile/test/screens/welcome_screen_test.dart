// ABOUTME: Tests for WelcomeScreen
// ABOUTME: Verifies default variant, returning-user variant, button interactions,
// ABOUTME: terms notice, error display, and loading states

import 'package:db_client/db_client.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/welcome/welcome_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/widgets/auth/auth_hero_section.dart';
import 'package:openvine/widgets/error_message.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

const _testPubkeyHex =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

final _testProfile = UserProfile(
  pubkey: _testPubkeyHex,
  displayName: 'Test User',
  picture: 'https://example.com/avatar.png',
  nip05: 'testuser@example.com',
  rawData: const {},
  createdAt: DateTime(2024),
  eventId: 'e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8',
);

void main() {
  late _MockAuthService mockAuthService;
  late _MockAppDatabase mockDb;
  late _MockUserProfilesDao mockUserProfilesDao;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    mockAuthService = _MockAuthService();
    mockDb = _MockAppDatabase();
    mockUserProfilesDao = _MockUserProfilesDao();

    when(() => mockDb.userProfilesDao).thenReturn(mockUserProfilesDao);
    when(
      () => mockUserProfilesDao.getProfile(any()),
    ).thenAnswer((_) async => null);

    // Default stubs
    when(() => mockAuthService.lastError).thenReturn(null);
    when(() => mockAuthService.authState).thenReturn(AuthState.unauthenticated);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockAuthService.signInAutomatically()).thenAnswer((_) async {});
    when(() => mockAuthService.acceptTerms()).thenAnswer((_) async {});
    when(
      () => mockAuthService.signOut(deleteKeys: true),
    ).thenAnswer((_) async {});
  });

  Widget createTestWidget({AuthState authState = AuthState.unauthenticated}) {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        currentAuthStateProvider.overrideWithValue(authState),
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(mockDb),
      ],
      child: MaterialApp.router(
        theme: VineTheme.theme,
        routerConfig: GoRouter(
          initialLocation: WelcomeScreen.path,
          routes: [
            GoRoute(
              path: WelcomeScreen.path,
              builder: (context, state) => const WelcomeScreen(),
              routes: [
                GoRoute(
                  path: 'create-account',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Create Account')),
                ),
                GoRoute(
                  path: 'login-options',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Sign in')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  group(WelcomeScreen, () {
    group('default variant', () {
      testWidgets('displays $AuthHeroSection', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthHeroSection), findsOneWidget);
      });

      testWidgets('displays create account button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Create new diVine account'), findsOneWidget);
      });

      testWidgets('displays login button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Login with a different account'), findsOneWidget);
      });

      testWidgets('displays terms notice with legal links', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final richTextFinder = find.byWidgetPredicate((widget) {
          if (widget is RichText) {
            final text = widget.text.toPlainText();
            return text.contains('Terms of Service') &&
                text.contains('Privacy Policy') &&
                text.contains('Safety Standards');
          }
          return false;
        });
        expect(richTextFinder, findsOneWidget);
      });

      testWidgets('tapping create account calls acceptTerms and navigates', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create new diVine account'));
        await tester.pumpAndSettle();

        verify(() => mockAuthService.acceptTerms()).called(1);
        expect(find.text('Create Account'), findsOneWidget);
      });

      testWidgets('tapping login button calls acceptTerms and navigates', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Login with a different account'));
        await tester.pumpAndSettle();

        verify(() => mockAuthService.acceptTerms()).called(1);
        expect(find.text('Sign in'), findsOneWidget);
      });

      testWidgets('shows error when lastError is set', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        when(() => mockAuthService.lastError).thenReturn('Auth failed');

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ErrorMessage), findsOneWidget);
        expect(find.text('Auth failed'), findsOneWidget);
      });

      testWidgets('does not show error when lastError is null', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ErrorMessage), findsNothing);
      });

      testWidgets('shows loading indicator when auth state is checking', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(authState: AuthState.checking),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows loading indicator when auth state is authenticating', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(authState: AuthState.authenticating),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('login button disabled when auth state is checking', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(authState: AuthState.checking),
        );
        await tester.pump();

        await tester.tap(find.text('Login with a different account'));
        await tester.pump();

        verifyNever(() => mockAuthService.acceptTerms());
      });
    });

    group('returning user variant', () {
      setUp(() async {
        await prefs.setString(kLastUserPubkeyHexKey, _testPubkeyHex);
        when(
          () => mockUserProfilesDao.getProfile(_testPubkeyHex),
        ).thenAnswer((_) async => _testProfile);
      });

      testWidgets('shows "Welcome back!" title', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Welcome back!'), findsOneWidget);
      });

      testWidgets('shows user avatar', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('shows display name', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Test User'), findsOneWidget);
      });

      testWidgets('shows NIP-05 identifier', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('testuser@example.com'), findsOneWidget);
      });

      testWidgets('does not show $AuthHeroSection', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthHeroSection), findsNothing);
      });

      testWidgets('shows "Log back in" button', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Log back in'), findsOneWidget);
      });

      testWidgets('shows "Create a new diVine account" button', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Create a new diVine account'), findsOneWidget);
      });

      testWidgets('tapping "Log back in" calls signInAutomatically', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log back in'));
        await tester.pump();

        verify(() => mockAuthService.signInAutomatically()).called(1);
      });

      testWidgets(
        'tapping "Create a new diVine account" shows confirmation bottom sheet',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          await tester.tap(find.text('Create a new diVine account'));
          await tester.pumpAndSettle();

          expect(find.text('Create a new Divine account?'), findsOneWidget);
          expect(find.text('Start fresh'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);
        },
      );

      testWidgets('confirming "Start fresh" calls signOut with deleteKeys', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create a new diVine account'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start fresh'));
        await tester.pump();

        verify(() => mockAuthService.signOut(deleteKeys: true)).called(1);
      });

      testWidgets('tapping "Cancel" on bottom sheet does not call signOut', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create a new diVine account'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(() => mockAuthService.signOut(deleteKeys: true));
      });

      testWidgets('tapping login button calls acceptTerms and navigates', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Login with a different account'));
        await tester.pumpAndSettle();

        verify(() => mockAuthService.acceptTerms()).called(1);
        expect(find.text('Sign in'), findsOneWidget);
      });
    });
  });
}
