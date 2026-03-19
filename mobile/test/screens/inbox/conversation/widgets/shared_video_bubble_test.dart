// ABOUTME: Widget tests for SharedVideoBubble.
// ABOUTME: Tests loading state, error state, layout, and timestamp rendering
// ABOUTME: using mocked Riverpod providers.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/shared_video_bubble.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group(SharedVideoBubble, () {
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();

      when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
      when(
        () => mockNostrClient.fetchEventById(any()),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({
      bool isSent = false,
      bool isFirstInGroup = true,
      bool isLastInGroup = true,
    }) {
      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SharedVideoBubble(
              videoEventId: 'a' * 64,
              timestamp: '9:41 AM',
              isSent: isSent,
              isFirstInGroup: isFirstInGroup,
              isLastInGroup: isLastInGroup,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('shows error state when video not found', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Video unavailable'), findsOneWidget);
      });

      testWidgets('aligns right for sent messages', (tester) async {
        await tester.pumpWidget(buildSubject(isSent: true));

        final align = tester.widget<Align>(find.byType(Align));
        expect(align.alignment, equals(Alignment.centerRight));
      });

      testWidgets('aligns left for received messages', (tester) async {
        await tester.pumpWidget(buildSubject());

        final align = tester.widget<Align>(find.byType(Align));
        expect(align.alignment, equals(Alignment.centerLeft));
      });

      testWidgets('renders timestamp when isFirstInGroup', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('9:41 AM'), findsOneWidget);
      });

      testWidgets('hides timestamp when not isFirstInGroup', (tester) async {
        await tester.pumpWidget(buildSubject(isFirstInGroup: false));

        expect(find.text('9:41 AM'), findsNothing);
      });

      testWidgets('uses sent bubble color', (tester) async {
        await tester.pumpWidget(buildSubject(isSent: true));

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color ==
                    VineTheme.primaryAccessible,
          ),
          findsOneWidget,
        );
      });

      testWidgets('uses received bubble color', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color ==
                    VineTheme.containerLow,
          ),
          findsOneWidget,
        );
      });
    });
  });
}
