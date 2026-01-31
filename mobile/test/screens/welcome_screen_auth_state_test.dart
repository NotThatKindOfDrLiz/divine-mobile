// ABOUTME: Widget test for welcome screen legal acceptance functionality
// ABOUTME: Verifies checkboxes, validation errors, and submit behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/legal_checkbox.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([AuthService])
import 'welcome_screen_auth_state_test.mocks.dart';

void main() {
  group('WelcomeScreen Legal Acceptance Tests', () {
    late MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = MockAuthService();

      // Default mock setup
      when(mockAuthService.acceptTerms()).thenAnswer((_) async {});
    });

    Widget buildTestWidget({bool useGoRouter = false}) {
      final widget = useGoRouter
          ? MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: WelcomeScreen.path,
                routes: [
                  GoRoute(
                    path: WelcomeScreen.path,
                    builder: (context, state) => const WelcomeScreen(),
                  ),
                  // Dummy route for navigation target
                  GoRoute(
                    path: '/welcome/auth-native',
                    builder: (context, state) =>
                        const Scaffold(body: Text('Auth Screen')),
                  ),
                ],
              ),
            )
          : const MaterialApp(home: WelcomeScreen());

      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
        child: widget,
      );
    }

    // Helper to get age checkbox (index 0)
    Finder findAgeCheckbox() => find.byType(LegalCheckbox).at(0);

    // Helper to get terms checkbox (index 1)
    Finder findTermsCheckbox() => find.byType(LegalCheckbox).at(1);

    testWidgets('shows age and terms checkboxes initially unchecked', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify both checkboxes are present
      expect(find.text('I am 16 years or older'), findsOneWidget);
      expect(find.byType(LegalCheckbox), findsNWidgets(2));

      // Verify checkboxes are unchecked
      final checkboxes = tester.widgetList<LegalCheckbox>(
        find.byType(LegalCheckbox),
      );
      expect(checkboxes.length, equals(2));

      for (final checkbox in checkboxes) {
        expect(checkbox.checked, isFalse);
      }

      // Verify Accept button is present
      expect(find.text('Accept & continue'), findsOneWidget);
    });

    testWidgets('toggles age verification checkbox when tapped', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the age checkbox (first one)
      await tester.tap(findAgeCheckbox());
      await tester.pumpAndSettle();

      // Verify checkbox is now checked
      final checkbox = tester.widget<LegalCheckbox>(findAgeCheckbox());
      expect(checkbox.checked, isTrue);
    });

    testWidgets('toggles terms acceptance checkbox when tapped', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the terms checkbox (second one)
      await tester.tap(findTermsCheckbox());
      await tester.pumpAndSettle();

      // Verify checkbox is now checked
      final checkbox = tester.widget<LegalCheckbox>(findTermsCheckbox());
      expect(checkbox.checked, isTrue);
    });

    testWidgets('shows error state when submitting without checking age', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check only terms (not age)
      await tester.tap(findTermsCheckbox());
      await tester.pumpAndSettle();

      // Tap Accept button
      await tester.tap(find.text('Accept & continue'));
      await tester.pumpAndSettle();

      // Verify age checkbox shows error (showError = true)
      final ageCheckbox = tester.widget<LegalCheckbox>(findAgeCheckbox());
      expect(ageCheckbox.showError, isTrue);

      // AuthService.acceptTerms should NOT be called
      verifyNever(mockAuthService.acceptTerms());
    });

    testWidgets('shows error state when submitting without checking terms', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check only age (not terms)
      await tester.tap(findAgeCheckbox());
      await tester.pumpAndSettle();

      // Tap Accept button
      await tester.tap(find.text('Accept & continue'));
      await tester.pumpAndSettle();

      // Verify terms checkbox shows error (showError = true)
      final termsCheckbox = tester.widget<LegalCheckbox>(findTermsCheckbox());
      expect(termsCheckbox.showError, isTrue);

      // AuthService.acceptTerms should NOT be called
      verifyNever(mockAuthService.acceptTerms());
    });

    testWidgets('calls AuthService.acceptTerms when both checkboxes checked', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      // Use GoRouter for this test since it tests successful submission which triggers navigation
      await tester.pumpWidget(buildTestWidget(useGoRouter: true));
      await tester.pumpAndSettle();

      // Check age checkbox
      await tester.tap(findAgeCheckbox());
      await tester.pumpAndSettle();

      // Check terms checkbox
      await tester.tap(findTermsCheckbox());
      await tester.pumpAndSettle();

      // Tap Accept button
      await tester.tap(find.text('Accept & continue'));
      await tester.pumpAndSettle();

      // Verify AuthService.acceptTerms was called
      verify(mockAuthService.acceptTerms()).called(1);
    });

    testWidgets('loads previously saved acceptance state from preferences', (
      tester,
    ) async {
      // Pre-populate SharedPreferences with saved state
      SharedPreferences.setMockInitialValues({
        'age_verified_16_plus': true,
        'terms_accepted_at': '2024-01-01T00:00:00.000Z',
      });
      final prefsWithSavedState = await SharedPreferences.getInstance();

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefsWithSavedState),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both checkboxes are checked (loaded from prefs)
      final checkboxes = tester.widgetList<LegalCheckbox>(
        find.byType(LegalCheckbox),
      );

      for (final checkbox in checkboxes) {
        expect(checkbox.checked, isTrue);
      }
    });

    testWidgets('shows branding elements', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify tagline is shown
      expect(
        find.text('Create and share short videos\non the decentralized web'),
        findsOneWidget,
      );
    });
  });
}
