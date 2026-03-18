// ABOUTME: Widget tests for MessageBubble.
// ABOUTME: Tests rendering of message text, timestamp visibility,
// ABOUTME: alignment for sent vs received messages, and URL link detection.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_bubble.dart';

void main() {
  group(MessageBubble, () {
    group('renders', () {
      testWidgets('renders message text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Hello there',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('Hello there'), findsOneWidget);
      });

      testWidgets(
        'renders timestamp when isFirstInGroup is true',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MessageBubble(
                  message: 'Hello there',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          );

          expect(find.text('2:30 PM'), findsOneWidget);
        },
      );

      testWidgets(
        'does not render timestamp when isFirstInGroup is false',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MessageBubble(
                  message: 'Hello there',
                  timestamp: '2:30 PM',
                  isSent: true,
                  isFirstInGroup: false,
                ),
              ),
            ),
          );

          expect(find.text('2:30 PM'), findsNothing);
        },
      );

      testWidgets('aligns right for sent messages', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Sent message',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));

        expect(align.alignment, equals(Alignment.centerRight));
      });

      testWidgets('aligns left for received messages', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Received message',
                timestamp: '2:30 PM',
                isSent: false,
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));

        expect(align.alignment, equals(Alignment.centerLeft));
      });
    });

    group('links', () {
      testWidgets('renders plain message without URLs as $Text', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'No links here',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        // Plain text uses a simple Text widget, not RichText with spans.
        expect(find.text('No links here'), findsOneWidget);
      });

      testWidgets('renders URL as tappable RichText with underline', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'https://divine.video/video/abc123',
                timestamp: '2:30 PM',
                isSent: false,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) => w is RichText && _hasTextSpanWithUrl(w.text),
          ),
        );

        final span = _findUrlSpan(richText.text);
        expect(span, isNotNull);
        expect(span!.text, equals('https://divine.video/video/abc123'));
        expect(span.style?.decoration, equals(TextDecoration.underline));
        expect(span.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('renders mixed text and URL as separate spans', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Check this https://example.com cool!',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) => w is RichText && _hasTextSpanWithUrl(w.text),
          ),
        );

        final urlSpans = _findAllUrlSpans(richText.text);
        expect(urlSpans, hasLength(1));
        expect(urlSpans[0].text, equals('https://example.com'));

        // Verify the full text is present (plain + link parts).
        final fullText = richText.text.toPlainText();
        expect(fullText, contains('Check this '));
        expect(fullText, contains('https://example.com'));
        expect(fullText, contains(' cool!'));
      });

      testWidgets('renders multiple URLs each with recognizer', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'https://a.com and https://b.com',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) => w is RichText && _hasTextSpanWithUrl(w.text),
          ),
        );

        final urlSpans = _findAllUrlSpans(richText.text);
        expect(urlSpans, hasLength(2));
        expect(urlSpans[0].text, equals('https://a.com'));
        expect(urlSpans[0].recognizer, isA<TapGestureRecognizer>());
        expect(urlSpans[1].text, equals('https://b.com'));
        expect(urlSpans[1].recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('calls onLinkTap when provided', (tester) async {
        String? tappedUrl;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Visit https://divine.video',
                timestamp: '2:30 PM',
                isSent: true,
                onLinkTap: (url) => tappedUrl = url,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) => w is RichText && _hasTextSpanWithUrl(w.text),
          ),
        );

        final span = _findUrlSpan(richText.text);
        (span!.recognizer! as TapGestureRecognizer).onTap!();

        expect(tappedUrl, equals('https://divine.video'));
      });

      testWidgets('trims trailing punctuation from URLs', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'See https://example.com. Thanks!',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) => w is RichText && _hasTextSpanWithUrl(w.text),
          ),
        );

        final span = _findUrlSpan(richText.text);
        expect(span!.text, equals('https://example.com'));
      });
    });
  });
}

bool _hasTextSpanWithUrl(InlineSpan span) {
  if (span is TextSpan) {
    if (span.recognizer is TapGestureRecognizer) return true;
    if (span.children != null) {
      return span.children!.any(_hasTextSpanWithUrl);
    }
  }
  return false;
}

TextSpan? _findUrlSpan(InlineSpan span) {
  if (span is TextSpan) {
    if (span.recognizer is TapGestureRecognizer) return span;
    if (span.children != null) {
      for (final child in span.children!) {
        final found = _findUrlSpan(child);
        if (found != null) return found;
      }
    }
  }
  return null;
}

List<TextSpan> _findAllUrlSpans(InlineSpan span) {
  final results = <TextSpan>[];
  if (span is TextSpan) {
    if (span.recognizer is TapGestureRecognizer) {
      results.add(span);
    }
    if (span.children != null) {
      for (final child in span.children!) {
        results.addAll(_findAllUrlSpans(child));
      }
    }
  }
  return results;
}
