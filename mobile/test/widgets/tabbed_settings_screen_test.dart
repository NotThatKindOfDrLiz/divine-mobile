// ABOUTME: Widget tests for the current settings screen sections and subtitles
// ABOUTME: Verifies the reskinned screen preserves key settings functionality

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

const _testPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  late _MockAuthService mockAuthService;
  late SharedPreferences sharedPreferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    mockAuthService = _MockAuthService();

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.isAnonymous).thenReturn(false);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(_testPubkey);
    when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(false);
  });

  Widget createTestWidget({AuthState authState = AuthState.authenticated}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authServiceProvider.overrideWithValue(mockAuthService),
        currentAuthStateProvider.overrideWithValue(authState),
      ],
      child: MaterialApp(theme: VineTheme.theme, home: const SettingsScreen()),
    );
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('SettingsScreen Layout', () {
    testWidgets('renders Settings title and version footer row', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      final versionFinder = find.textContaining(
        'Version ',
        skipOffstage: false,
      );
      await scrollTo(tester, versionFinder);
      expect(find.textContaining('Version '), findsOneWidget);
    });

    testWidgets('renders current primary sections and key rows', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Safety & Privacy'), findsOneWidget);

      final nostrSettingsFinder = find.text(
        'Nostr Settings',
        skipOffstage: false,
      );
      await scrollTo(tester, nostrSettingsFinder);
      expect(find.text('Nostr Settings'), findsOneWidget);
      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Relay Diagnostics'), findsOneWidget);
      expect(find.text('Media Servers'), findsOneWidget);
      expect(find.text('Developer Options'), findsOneWidget);

      final supportFinder = find.text('Support', skipOffstage: false);
      await scrollTo(tester, supportFinder);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('ProofMode Info'), findsOneWidget);
      expect(find.text('Save Logs'), findsOneWidget);
    });
  });

  group('SettingsScreen Authentication-Dependent Sections', () {
    testWidgets(
      'renders account summary and account-only actions when authenticated',
      (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Currently logged in'), findsOneWidget);
        expect(find.text('Switch Account'), findsOneWidget);

        final accountToolsFinder = find.text(
          'Account Tools',
          skipOffstage: false,
        );
        await scrollTo(tester, accountToolsFinder);
        expect(find.text('Account Tools'), findsOneWidget);
        expect(find.text('Key Management'), findsOneWidget);
        expect(find.text('Remove Keys from Device'), findsOneWidget);

        final dangerZoneFinder = find.text('Danger Zone', skipOffstage: false);
        await scrollTo(tester, dangerZoneFinder);
        expect(find.text('Danger Zone'), findsOneWidget);
        expect(find.text('Delete Account and Data'), findsOneWidget);
      },
    );

    testWidgets('renders Secure Your Account row for anonymous users', (
      tester,
    ) async {
      when(() => mockAuthService.isAnonymous).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Local account'), findsOneWidget);
      expect(find.text('Secure Your Account'), findsOneWidget);
      expect(
        find.text('Add email and password to recover your account.'),
        findsOneWidget,
      );
    });

    testWidgets('hides account-only rows when not authenticated', (
      tester,
    ) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);
      when(() => mockAuthService.isAnonymous).thenReturn(false);

      await tester.pumpWidget(
        createTestWidget(authState: AuthState.unauthenticated),
      );
      await tester.pumpAndSettle();

      expect(find.text('Currently logged in'), findsNothing);
      expect(find.text('Switch Account'), findsNothing);
      expect(find.text('Account Tools'), findsNothing);
      expect(find.text('Danger Zone'), findsNothing);
      expect(find.text('Key Management'), findsNothing);
      expect(find.text('Delete Account and Data'), findsNothing);
    });
  });

  group('SettingsScreen Tile Subtitles', () {
    testWidgets('renders correct subtitles for Nostr settings rows', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Relays', skipOffstage: false));
      expect(find.text('Manage Nostr relay connections'), findsOneWidget);

      await scrollTo(
        tester,
        find.text('Relay Diagnostics', skipOffstage: false),
      );
      expect(
        find.text('Debug relay connectivity and network issues'),
        findsOneWidget,
      );

      await scrollTo(tester, find.text('Media Servers', skipOffstage: false));
      expect(find.text('Configure Blossom upload servers'), findsOneWidget);
    });

    testWidgets('renders correct subtitles for support rows', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Contact Support', skipOffstage: false));
      expect(find.text('Get help or report an issue'), findsOneWidget);

      await scrollTo(tester, find.text('ProofMode Info', skipOffstage: false));
      expect(
        find.text('Learn about ProofMode verification and authenticity'),
        findsOneWidget,
      );

      await scrollTo(tester, find.text('Save Logs', skipOffstage: false));
      expect(
        find.text('Export logs to file for manual sending'),
        findsOneWidget,
      );
    });
  });
}
