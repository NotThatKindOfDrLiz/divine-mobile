import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/broken_video_tracker.dart'
    show BrokenVideoTracker;
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_grid_tap_test.mocks.dart';

@GenerateNiceMocks([MockSpec<SharedPreferences>()])
void main() {
  group('ComposableVideoGrid tap handling', () {
    late MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = MockSharedPreferences();
    });

    List<VideoEvent> makeVideos(int count, {bool reposts = false}) =>
        List.generate(count, (i) {
          return VideoEvent(
            id: 'id_$i',
            pubkey: 'pk_$i',
            createdAt: 1,
            content: 'video $i',
            timestamp: DateTime(1),
            isRepost: reposts,
          );
        });

    testWidgets(
      'Profile videos grid: tapping first tile reports correct video',
      (tester) async {
        final videos = makeVideos(5, reposts: false);
        VideoEvent? tappedVideo;
        int? tappedIndex;

        final fakeTracker = BrokenVideoTracker();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              brokenVideoTrackerProvider.overrideWithValue(
                AsyncValue.data(fakeTracker),
              ),
              sharedPreferencesProvider.overrideWithValue(mockPrefs),
              subscribedListVideoCacheProvider.overrideWithValue(null),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: videos,
                  onVideoTap: (list, idx) {},
                  tileBuilder: (video, idx) => GestureDetector(
                    key: ValueKey('videos-tile-$idx'),
                    onTap: () {
                      tappedVideo = video;
                      tappedIndex = idx;
                    },
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Text(video.id),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('videos-tile-0')));
        expect(tappedIndex, 0);
        expect(tappedVideo?.id, 'id_0');
      },
    );

    testWidgets('Liked grid: tapping first tile reports correct liked video', (
      tester,
    ) async {
      final liked = makeVideos(4, reposts: false);
      VideoEvent? tappedVideo;
      int? tappedIndex;

      final fakeTracker = BrokenVideoTracker();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokenVideoTrackerProvider.overrideWithValue(
              AsyncValue.data(fakeTracker),
            ),
            sharedPreferencesProvider.overrideWithValue(mockPrefs),
            subscribedListVideoCacheProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: liked,
                onVideoTap: (list, idx) {},
                tileBuilder: (video, idx) => GestureDetector(
                  key: ValueKey('liked-tile-$idx'),
                  onTap: () {
                    tappedVideo = video;
                    tappedIndex = idx;
                  },
                  child: SizedBox(width: 90, height: 90, child: Text(video.id)),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('liked-tile-0')));
      expect(tappedIndex, 0);
      expect(tappedVideo?.id, 'id_0');
    });

    testWidgets(
      'Reposts grid: tapping first tile reports correct repost video',
      (tester) async {
        final reposts = makeVideos(3, reposts: true);
        VideoEvent? tappedVideo;
        int? tappedIndex;

        final fakeTracker = BrokenVideoTracker();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              brokenVideoTrackerProvider.overrideWithValue(
                AsyncValue.data(fakeTracker),
              ),
              sharedPreferencesProvider.overrideWithValue(mockPrefs),
              subscribedListVideoCacheProvider.overrideWithValue(null),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: reposts,
                  onVideoTap: (list, idx) {},
                  tileBuilder: (video, idx) => GestureDetector(
                    key: ValueKey('repost-tile-$idx'),
                    onTap: () {
                      tappedVideo = video;
                      tappedIndex = idx;
                    },
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Text(video.id),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('repost-tile-0')));
        expect(tappedIndex, 0);
        expect(tappedVideo?.id, 'id_0');
      },
    );
  });
}
