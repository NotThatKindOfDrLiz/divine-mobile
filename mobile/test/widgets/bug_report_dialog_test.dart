// ABOUTME: Widget tests for BugReportDialog user interface
// ABOUTME: Tests UI rendering, user interaction, form validation, and
// dialog dismiss paths

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show BugReportData;
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';

class _MockBugReportService extends Mock implements BugReportService {}

void main() {
  group(BugReportDialog, () {
    late _MockBugReportService mockBugReportService;

    setUp(() {
      mockBugReportService = _MockBugReportService();
    });

    Widget buildSubject({String? userPubkey}) {
      return MaterialApp(
        home: Scaffold(
          body: BugReportDialog(
            bugReportService: mockBugReportService,
            userPubkey: userPubkey,
          ),
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
                  builder: (_) => BugReportDialog(
                    bugReportService: mockBugReportService,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
    }

    BugReportData buildTestReportData() {
      return BugReportData(
        reportId: 'test-123',
        userDescription: 'App crashed on startup',
        deviceInfo: {'platform': 'ios', 'version': '17.0'},
        appVersion: '1.0.0+42',
        recentLogs: [],
        errorCounts: {},
        timestamp: DateTime.now(),
      );
    }

    group('renders', () {
      testWidgets('title and all form fields', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('Report a Bug'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(4));
        expect(find.text('Subject *'), findsOneWidget);
        expect(find.text('What happened? *'), findsOneWidget);
        expect(find.text('Steps to Reproduce'), findsOneWidget);
        expect(find.text('Expected Behavior'), findsOneWidget);
      });

      testWidgets('$ElevatedButton and $TextButton buttons', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('Send Report'), findsOneWidget);
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
              of: find.text('Send Report'),
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

          await tester.enterText(find.byType(TextField).at(0), 'App crashed');
          await tester.pump();
          await tester.enterText(
            find.byType(TextField).at(1),
            'App crashed on startup',
          );
          await tester.pump();

          final button = tester.widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Send Report'),
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

          await tester.enterText(find.byType(TextField).at(0), 'App crashed');
          await tester.pump();

          final button = tester.widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Send Report'),
              matching: find.byType(ElevatedButton),
            ),
          );
          expect(button.onPressed, isNull);
        },
      );
    });

    group('interactions', () {
      testWidgets('calls collectDiagnostics on submit', (tester) async {
        when(
          () => mockBugReportService.collectDiagnostics(
            userDescription: any(named: 'userDescription'),
            currentScreen: any(named: 'currentScreen'),
            userPubkey: any(named: 'userPubkey'),
            additionalContext: any(named: 'additionalContext'),
          ),
        ).thenAnswer((_) async => buildTestReportData());

        await tester.pumpWidget(buildSubject());

        await tester.enterText(find.byType(TextField).at(0), 'App crashed');
        await tester.pump();
        await tester.enterText(
          find.byType(TextField).at(1),
          'App crashed on startup',
        );
        await tester.pump();

        await tester.tap(find.text('Send Report'));
        await tester.pump();

        verify(
          () => mockBugReportService.collectDiagnostics(
            userDescription: any(named: 'userDescription'),
            currentScreen: any(named: 'currentScreen'),
            userPubkey: any(named: 'userPubkey'),
            additionalContext: any(named: 'additionalContext'),
          ),
        ).called(1);
      });

      testWidgets('shows loading indicator while submitting', (tester) async {
        when(
          () => mockBugReportService.collectDiagnostics(
            userDescription: any(named: 'userDescription'),
            currentScreen: any(named: 'currentScreen'),
            userPubkey: any(named: 'userPubkey'),
            additionalContext: any(named: 'additionalContext'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return buildTestReportData();
        });

        await tester.pumpWidget(buildSubject());

        await tester.enterText(find.byType(TextField).at(0), 'App crashed');
        await tester.pump();
        await tester.enterText(
          find.byType(TextField).at(1),
          'App crashed on startup',
        );
        await tester.pump();

        await tester.tap(find.text('Send Report'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();
      });

      testWidgets('closes dialog on Cancel', (tester) async {
        await tester.pumpWidget(buildDialogSubject());

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Report a Bug'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog should be dismissed — title no longer visible
        expect(find.text('Report a Bug'), findsNothing);
      });
    });
  });
}
