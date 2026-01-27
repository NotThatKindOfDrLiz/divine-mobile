// ABOUTME: Tests for LegalScreen
// ABOUTME: Verifies checkbox interactions, error states, and navigation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/legal_screen.dart';
import 'package:openvine/widgets/legal_checkbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: VineTheme.theme,
        home: const LegalScreen(),
      ),
    );
  }

  group('LegalScreen', () {
    testWidgets('displays age verification checkbox', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('I am 16 years or older'), findsOneWidget);
    });

    testWidgets('displays terms acceptance checkbox with links', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // RichText renders as a single widget, so we find it by checking its content
      final richTextFinder = find.byWidgetPredicate(
        (widget) {
          if (widget is RichText) {
            final text = widget.text.toPlainText();
            return text.contains('Terms of Service') &&
                text.contains('Privacy Policy') &&
                text.contains('Safety Standards');
          }
          return false;
        },
      );
      expect(richTextFinder, findsOneWidget);
    });

    testWidgets('displays Accept & continue button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Accept & continue'), findsOneWidget);
    });

    testWidgets('checkboxes are unchecked by default', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      for (final checkbox in checkboxes) {
        expect(checkbox.value, false);
      }
    });

    testWidgets('tapping age checkbox toggles it', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the age checkbox by its parent LegalCheckbox containing the text
      final ageCheckboxFinder = find.ancestor(
        of: find.text('I am 16 years or older'),
        matching: find.byType(LegalCheckbox),
      );

      await tester.tap(ageCheckboxFinder);
      await tester.pumpAndSettle();

      // Find the checkbox within the age LegalCheckbox
      final checkbox = tester.widget<Checkbox>(
        find.descendant(
          of: ageCheckboxFinder,
          matching: find.byType(Checkbox),
        ),
      );
      expect(checkbox.value, true);
    });

    testWidgets('tapping terms checkbox toggles it', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the terms checkbox - it's the second LegalCheckbox
      final termsCheckboxFinder = find.byType(LegalCheckbox).last;

      await tester.tap(termsCheckboxFinder);
      await tester.pumpAndSettle();

      final checkbox = tester.widget<Checkbox>(
        find.descendant(
          of: termsCheckboxFinder,
          matching: find.byType(Checkbox),
        ),
      );
      expect(checkbox.value, true);
    });

    testWidgets(
      'submitting without checking shows red borders on unchecked items',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap submit without checking anything
        await tester.tap(find.text('Accept & continue'));
        await tester.pumpAndSettle();

        // Both checkboxes should now have error state (red border)
        final containers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(LegalCheckbox),
                matching: find.byType(Container),
              ),
            )
            .where((c) => c.decoration != null);

        for (final container in containers) {
          final decoration = container.decoration as BoxDecoration?;
          final border = decoration?.border as Border?;
          if (border != null) {
            expect(border.top.color, VineTheme.error);
          }
        }
      },
    );

    testWidgets('checking one box and submitting shows error only on unchecked',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check age only
      final ageCheckboxFinder = find.ancestor(
        of: find.text('I am 16 years or older'),
        matching: find.byType(LegalCheckbox),
      );
      await tester.tap(ageCheckboxFinder);
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Accept & continue'));
      await tester.pumpAndSettle();

      // Age checkbox should have green border (checked, no error)
      final ageContainer = tester.widget<Container>(
        find.descendant(of: ageCheckboxFinder, matching: find.byType(Container))
            .first,
      );
      final ageDecoration = ageContainer.decoration as BoxDecoration?;
      final ageBorder = ageDecoration?.border as Border?;
      expect(ageBorder?.top.color, VineTheme.vineGreen);

      // Terms checkbox should have red border (unchecked, error)
      final termsCheckboxFinder = find.byType(LegalCheckbox).last;
      final termsContainer = tester.widget<Container>(
        find.descendant(
          of: termsCheckboxFinder,
          matching: find.byType(Container),
        ).first,
      );
      final termsDecoration = termsContainer.decoration as BoxDecoration?;
      final termsBorder = termsDecoration?.border as Border?;
      expect(termsBorder?.top.color, VineTheme.error);
    });

    testWidgets('pre-populates checkboxes from SharedPreferences', (
      tester,
    ) async {
      // Set up saved state
      await prefs.setBool('age_verified_16_plus', true);
      await prefs.setString('terms_accepted_at', '2024-01-01T00:00:00.000Z');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Both checkboxes should be checked
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      for (final checkbox in checkboxes) {
        expect(checkbox.value, true);
      }
    });

    testWidgets('displays Divine branding', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for tagline
      expect(
        find.text('Create and share short videos\non the decentralized web'),
        findsOneWidget,
      );
    });
  });
}
