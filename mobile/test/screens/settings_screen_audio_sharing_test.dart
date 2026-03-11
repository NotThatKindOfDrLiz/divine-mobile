// ABOUTME: Tests for audio sharing preference toggle in settings screen
// ABOUTME: Verifies toggle displays and persists user preference

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

void main() {
  group('SettingsScreen Audio Sharing Toggle', () {
    late _MockAuthService mockAuthService;
    late _MockAudioSharingPreferenceService mockAudioSharingService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      mockAudioSharingService = _MockAudioSharingPreferenceService();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(false);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(
        () => mockAuthService.hasExpiredOAuthSession,
      ).thenReturn(false);
      when(
        () => mockAudioSharingService.isAudioSharingEnabled,
      ).thenReturn(false);
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          audioSharingPreferenceServiceProvider.overrideWithValue(
            mockAudioSharingService,
          ),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        ],
        child: MaterialApp(
          theme: VineTheme.theme,
          home: const SettingsScreen(),
        ),
      );
    }

    Finder audioSharingTitle() =>
        find.text('Make my audio available for reuse', skipOffstage: false);

    Future<void> scrollToAudioSharingToggle(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        audioSharingTitle(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('displays audio sharing toggle in Preferences section', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await scrollToAudioSharingToggle(tester);

      // Should find the toggle in the Preferences section
      expect(find.text('Make my audio available for reuse'), findsOneWidget);
      expect(
        find.text('When enabled, others can use audio from your videos'),
        findsOneWidget,
      );
    });

    testWidgets('toggle shows correct initial state (OFF)', (tester) async {
      when(
        () => mockAudioSharingService.isAudioSharingEnabled,
      ).thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await scrollToAudioSharingToggle(tester);

      final audioSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(audioSwitch.value, isFalse);
    });

    testWidgets('toggle shows correct initial state (ON)', (tester) async {
      when(
        () => mockAudioSharingService.isAudioSharingEnabled,
      ).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await scrollToAudioSharingToggle(tester);

      final audioSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(audioSwitch.value, isTrue);
    });

    testWidgets('tapping toggle calls setAudioSharingEnabled', (tester) async {
      when(
        () => mockAudioSharingService.isAudioSharingEnabled,
      ).thenReturn(false);
      when(
        () => mockAudioSharingService.setAudioSharingEnabled(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await scrollToAudioSharingToggle(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify the service was called
      verify(
        () => mockAudioSharingService.setAudioSharingEnabled(true),
      ).called(1);
    });

    testWidgets('uses correct VineTheme colors', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await scrollToAudioSharingToggle(tester);

      final audioSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(audioSwitch.activeThumbColor, VineTheme.vineGreen);
    });
  });
}
