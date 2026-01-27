// ABOUTME: Tests for LegalCheckbox widget
// ABOUTME: Verifies border color states and tap handling

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/legal_checkbox.dart';

void main() {
  group('LegalCheckbox', () {
    testWidgets('displays child content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: false,
              onChanged: () {},
              child: const Text('Test content'),
            ),
          ),
        ),
      );

      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('shows unchecked checkbox when checked is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: false,
              onChanged: () {},
              child: const Text('Test'),
            ),
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, false);
    });

    testWidgets('shows checked checkbox when checked is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: true,
              onChanged: () {},
              child: const Text('Test'),
            ),
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, true);
    });

    testWidgets('calls onChanged when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: false,
              onChanged: () => tapped = true,
              child: const Text('Test'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LegalCheckbox));
      expect(tapped, true);
    });

    testWidgets('calls onChanged when checkbox is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: false,
              onChanged: () => tapped = true,
              child: const Text('Test'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Checkbox));
      expect(tapped, true);
    });

    testWidgets('has muted green border when unchecked and no error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: false,
              onChanged: () {},
              child: const Text('Test'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(LegalCheckbox),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      final border = decoration?.border as Border?;

      expect(border?.top.color, VineTheme.outlineVariant);
    });

    testWidgets('has bright green border when checked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: true,
              onChanged: () {},
              child: const Text('Test'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(LegalCheckbox),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      final border = decoration?.border as Border?;

      expect(border?.top.color, VineTheme.vineGreen);
    });

    testWidgets('has red border when showError is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: false,
              showError: true,
              onChanged: () {},
              child: const Text('Test'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(LegalCheckbox),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      final border = decoration?.border as Border?;

      expect(border?.top.color, VineTheme.error);
    });

    testWidgets('error state takes precedence over checked state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegalCheckbox(
              checked: true,
              showError: true,
              onChanged: () {},
              child: const Text('Test'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(LegalCheckbox),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      final border = decoration?.border as Border?;

      // Error color should take precedence
      expect(border?.top.color, VineTheme.error);
    });
  });
}
