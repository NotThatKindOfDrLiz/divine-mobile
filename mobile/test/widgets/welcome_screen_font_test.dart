// ABOUTME: Widget test for welcome screen layout and text rendering
// ABOUTME: Verifies that the welcome screen displays correctly with legal checkboxes

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/legal_checkbox.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([AuthService])
import 'welcome_screen_font_test.mocks.dart';

void main() {
  group('WelcomeScreen Layout Tests', () {
    late MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      mockAuthService = MockAuthService();
      when(mockAuthService.authState).thenReturn(AuthState.unauthenticated);
      when(mockAuthService.isAuthenticated).thenReturn(false);
      when(mockAuthService.lastError).thenReturn(null);
      // Stub for hasSavedKeys - called in WelcomeScreen.initState
      when(mockAuthService.hasSavedKeys()).thenAnswer((_) async => false);
    });

    testWidgets('Welcome screen layout renders correctly', (tester) async {
      // Set larger test size to prevent overflow
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      );

      // Allow widget to build
      await tester.pumpAndSettle();

      // Verify key elements are present
      expect(
        find.text('Create and share short videos\non the decentralized web'),
        findsOneWidget,
      );

      // Verify legal checkboxes are present (2 checkboxes: age and terms)
      expect(find.text('I am 16 years or older'), findsOneWidget);
      // Terms checkbox contains RichText, verify via LegalCheckbox count
      expect(find.byType(LegalCheckbox), findsNWidgets(2));

      // Verify Accept button is present
      expect(find.text('Accept & continue'), findsOneWidget);
    });
  });
}
