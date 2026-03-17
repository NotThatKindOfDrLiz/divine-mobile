// ABOUTME: Unit tests for VideoFeedRetainedCache and RetainedVideoFeedSnapshot
// ABOUTME: Validates cache read/write/clear/clearAll and snapshot equality

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';

void main() {
  VideoEvent createTestVideo(String id) {
    const timestamp = 1700000000;
    return VideoEvent(
      id: id,
      pubkey: '0' * 64,
      createdAt: timestamp,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
      title: 'Test Video $id',
      videoUrl: 'https://example.com/$id.mp4',
      thumbnailUrl: 'https://example.com/$id.jpg',
    );
  }

  UserProfile createTestProfile(String pubkey) {
    return UserProfile(
      pubkey: pubkey,
      rawData: const <String, dynamic>{},
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      eventId: 'event-$pubkey',
      name: 'User $pubkey',
    );
  }

  group('InMemoryVideoFeedRetainedCache', () {
    late InMemoryVideoFeedRetainedCache cache;

    setUp(() {
      cache = InMemoryVideoFeedRetainedCache();
    });

    test('read returns null for unwritten mode', () {
      expect(cache.read(FeedMode.home), isNull);
      expect(cache.read(FeedMode.latest), isNull);
      expect(cache.read(FeedMode.popular), isNull);
    });

    test('read returns snapshot after write', () {
      final snapshot = RetainedVideoFeedSnapshot(
        mode: FeedMode.home,
        videos: [createTestVideo('v1')],
        hasMore: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026),
      );

      cache.write(snapshot);

      expect(cache.read(FeedMode.home), equals(snapshot));
    });

    test('write overwrites existing snapshot for same mode', () {
      final first = RetainedVideoFeedSnapshot(
        mode: FeedMode.home,
        videos: [createTestVideo('v1')],
        hasMore: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026),
      );
      final second = RetainedVideoFeedSnapshot(
        mode: FeedMode.home,
        videos: [createTestVideo('v2')],
        hasMore: false,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026, 2),
      );

      cache
        ..write(first)
        ..write(second);

      final result = cache.read(FeedMode.home);
      expect(result, equals(second));
      expect(result!.videos.first.id, equals('v2'));
    });

    test('clear removes snapshot for mode', () {
      final snapshot = RetainedVideoFeedSnapshot(
        mode: FeedMode.home,
        videos: [createTestVideo('v1')],
        hasMore: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026),
      );

      cache.write(snapshot);
      cache.clear(FeedMode.home);

      expect(cache.read(FeedMode.home), isNull);
    });

    test('clear does not affect other modes', () {
      final homeSnapshot = RetainedVideoFeedSnapshot(
        mode: FeedMode.home,
        videos: [createTestVideo('v1')],
        hasMore: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026),
      );
      final latestSnapshot = RetainedVideoFeedSnapshot(
        mode: FeedMode.latest,
        videos: [createTestVideo('v2')],
        hasMore: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026),
      );

      cache
        ..write(homeSnapshot)
        ..write(latestSnapshot);
      cache.clear(FeedMode.home);

      expect(cache.read(FeedMode.home), isNull);
      expect(cache.read(FeedMode.latest), equals(latestSnapshot));
    });

    test('clearAll removes all cached snapshots', () {
      final homeSnapshot = RetainedVideoFeedSnapshot(
        mode: FeedMode.home,
        videos: [createTestVideo('v1')],
        hasMore: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026),
      );
      final latestSnapshot = RetainedVideoFeedSnapshot(
        mode: FeedMode.latest,
        videos: [createTestVideo('v2')],
        hasMore: true,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026),
      );
      final popularSnapshot = RetainedVideoFeedSnapshot(
        mode: FeedMode.popular,
        videos: [createTestVideo('v3')],
        hasMore: false,
        videoListSources: const {},
        listOnlyVideoIds: const {},
        creatorProfiles: const {},
        refreshedAt: DateTime(2026),
      );

      cache
        ..write(homeSnapshot)
        ..write(latestSnapshot)
        ..write(popularSnapshot);
      cache.clearAll();

      expect(cache.read(FeedMode.home), isNull);
      expect(cache.read(FeedMode.latest), isNull);
      expect(cache.read(FeedMode.popular), isNull);
    });
  });

  group('RetainedVideoFeedSnapshot', () {
    test(
      'two snapshots with same data but different refreshedAt '
      'compare as equal',
      () {
        final videos = [createTestVideo('v1')];
        final profiles = {'pub1': createTestProfile('pub1')};

        final snapshotA = RetainedVideoFeedSnapshot(
          mode: FeedMode.home,
          videos: videos,
          hasMore: true,
          videoListSources: const {},
          listOnlyVideoIds: const {},
          creatorProfiles: profiles,
          refreshedAt: DateTime(2026),
        );
        final snapshotB = RetainedVideoFeedSnapshot(
          mode: FeedMode.home,
          videos: videos,
          hasMore: true,
          videoListSources: const {},
          listOnlyVideoIds: const {},
          creatorProfiles: profiles,
          refreshedAt: DateTime(2026, 6),
        );

        expect(snapshotA, equals(snapshotB));
      },
    );

    test(
      'two snapshots with different data compare as not equal',
      () {
        final snapshotA = RetainedVideoFeedSnapshot(
          mode: FeedMode.home,
          videos: [createTestVideo('v1')],
          hasMore: true,
          videoListSources: const {},
          listOnlyVideoIds: const {},
          creatorProfiles: const {},
          refreshedAt: DateTime(2026),
        );
        final snapshotB = RetainedVideoFeedSnapshot(
          mode: FeedMode.home,
          videos: [createTestVideo('v2')],
          hasMore: true,
          videoListSources: const {},
          listOnlyVideoIds: const {},
          creatorProfiles: const {},
          refreshedAt: DateTime(2026),
        );

        expect(snapshotA, isNot(equals(snapshotB)));
      },
    );
  });
}
