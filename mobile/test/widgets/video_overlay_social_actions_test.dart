// ABOUTME: Verifies the feed social action button widgets render together.
// ABOUTME: Guards against regressions where interaction controls disappear.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';

void main() {
  group('VideoOverlayActions social buttons', () {
    testWidgets('renders like/comment/repost/share actions', (tester) async {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'test-video-id',
        pubkey: 'test-pubkey',
        content: 'Test video',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColoredBox(
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  LikeActionButton(video: video),
                  CommentActionButton(video: video),
                  RepostActionButton(video: video),
                  ShareActionButton(video: video),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LikeActionButton), findsOneWidget);
      expect(find.byType(CommentActionButton), findsOneWidget);
      expect(find.byType(RepostActionButton), findsOneWidget);
      expect(find.byType(ShareActionButton), findsOneWidget);
    });
  });
}
