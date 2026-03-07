// ABOUTME: Widget tests for FeatureRequestDialog user interface
// ABOUTME: Tests UI rendering, form validation, and dialog dismiss paths

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';

void main() {
  group(FeatureRequestDialog, () {
    Widget buildSubject({String? userPubkey}) {
      return MaterialApp(
        home: Scaffold(
          body: FeatureRequestDialog(userPubkey: userPubkey),
        ),
      );
    }

    Widget buildDialogSubject() {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => const FeatureRequestDialog(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('title and all form fields', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('Request a Feature'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(4));
        expect(find.text('Subject *'), findsOneWidget);
        expect(find.text('What would you like? *'), findsOneWidget);
        expect(find.text('How would this be useful?'), findsOneWidget);
        expect(find.text('When would you use this?'), findsOneWidget);
      });

      testWidgets('Send Request and Cancel buttons', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('Send Request'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });
    });

    group('validation', () {
      testWidgets(
        'disables Send button when required fields are empty',
        (tester) async {
          await tester.pumpWidget(buildSubject());

          final button = tester.widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Send Request'),
              matching: find.byType(ElevatedButton),
            ),
          );
          expect(button.onPressed, isNull);
        },
      );

      testWidgets(
        'enables Send button when required fields are filled',
        (tester) async {
          await tester.pumpWidget(buildSubject());

          await tester.enterText(
            find.byType(TextField).at(0),
            'Dark mode calendar',
          );
          await tester.pump();
          await tester.enterText(
            find.byType(TextField).at(1),
            'A calendar view for scheduled posts',
          );
          await tester.pump();

          final button = tester.widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Send Request'),
              matching: find.byType(ElevatedButton),
            ),
          );
          expect(button.onPressed, isNotNull);
        },
      );

      testWidgets(
        'disables Send button when only subject is filled',
        (tester) async {
          await tester.pumpWidget(buildSubject());

          await tester.enterText(
            find.byType(TextField).at(0),
            'Dark mode calendar',
          );
          await tester.pump();

          final button = tester.widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Send Request'),
              matching: find.byType(ElevatedButton),
            ),
          );
          expect(button.onPressed, isNull);
        },
      );
    });

    group('interactions', () {
      testWidgets('closes dialog on Cancel', (tester) async {
        await tester.pumpWidget(buildDialogSubject());

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Request a Feature'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Request a Feature'), findsNothing);
      });
    });
  });
}
