// ABOUTME: Tests for reactive video stream patterns used by pooled feed screen
// ABOUTME: Tests both async* BLoC streams and broadcast controller provider streams

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  VideoEvent createTestVideo(String id) {
    final now = DateTime.now();
    return VideoEvent(
      id: id,
      pubkey: '0' * 64,
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      content: '',
      timestamp: now,
      title: 'Test Video $id',
      videoUrl: 'https://example.com/video_$id.mp4',
      thumbnailUrl: 'https://example.com/thumb_$id.jpg',
    );
  }

  group('Broadcast controller stream pattern (provider-style)', () {
    // Tests the createVideosStream() pattern used by Riverpod providers:
    // - Broadcast StreamController field on the notifier
    // - createVideosStream() returns a single-subscription forwarding stream
    // - Current videos emitted immediately (buffered)
    // - Future updates forwarded from broadcast controller

    late StreamController<List<VideoEvent>> broadcastController;

    setUp(() {
      broadcastController = StreamController<List<VideoEvent>>.broadcast();
    });

    tearDown(() {
      broadcastController.close();
    });

    /// Mimics the createVideosStream() method on our providers.
    Stream<List<VideoEvent>> createVideosStream({
      List<VideoEvent>? currentVideos,
    }) {
      final controller = StreamController<List<VideoEvent>>();
      late final StreamSubscription<List<VideoEvent>> sub;

      controller
        ..onListen = () {
          sub = broadcastController.stream.listen(
            controller.add,
            onError: controller.addError,
          );
        }
        ..onCancel = () {
          sub.cancel();
          controller.close();
        };

      // Emit current videos immediately (buffered until listened)
      if (currentVideos != null) {
        controller.add(currentVideos);
      }

      return controller.stream;
    }

    test('emits current videos immediately on listen', () async {
      final currentVideos = [createTestVideo('v1'), createTestVideo('v2')];

      final stream = createVideosStream(currentVideos: currentVideos);

      final firstEmission = await stream.first;
      expect(firstEmission.length, equals(2));
      expect(firstEmission[0].id, equals('v1'));
      expect(firstEmission[1].id, equals('v2'));
    });

    test('emits nothing initially when no current videos', () async {
      final stream = createVideosStream();

      // Should not emit anything until broadcast controller emits
      final completer = Completer<List<VideoEvent>>();
      final sub = stream.listen(completer.complete);

      // Give some time, then emit on broadcast
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(completer.isCompleted, isFalse);

      // Now emit on broadcast
      broadcastController.add([createTestVideo('v1')]);
      final result = await completer.future;
      expect(result.length, equals(1));

      await sub.cancel();
    });

    test('forwards updates from broadcast controller', () async {
      final emissions = <List<VideoEvent>>[];
      final stream = createVideosStream(currentVideos: [createTestVideo('v1')]);
      final sub = stream.listen(emissions.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Emit update
      broadcastController.add([createTestVideo('v1'), createTestVideo('v2')]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions.length, equals(2));
      expect(emissions[0].length, equals(1)); // initial
      expect(emissions[1].length, equals(2)); // update

      await sub.cancel();
    });

    test('cleans up on cancel', () async {
      final stream = createVideosStream(currentVideos: [createTestVideo('v1')]);
      final sub = stream.listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Cancel should not throw
      await sub.cancel();

      // Further emissions should not cause errors
      expect(
        () => broadcastController.add([createTestVideo('v2')]),
        returnsNormally,
      );
    });

    test('multiple createVideosStream calls produce independent streams', () {
      final emissions1 = <List<VideoEvent>>[];
      final emissions2 = <List<VideoEvent>>[];

      final stream1 = createVideosStream(
        currentVideos: [createTestVideo('v1')],
      );
      final stream2 = createVideosStream(
        currentVideos: [createTestVideo('v1'), createTestVideo('v2')],
      );

      final sub1 = stream1.listen(emissions1.add);
      final sub2 = stream2.listen(emissions2.add);

      // Both should get their own initial emissions
      expect(emissions1.length, equals(1));
      expect(emissions1[0].length, equals(1));
      expect(emissions2.length, equals(1));
      expect(emissions2[0].length, equals(2));

      sub1.cancel();
      sub2.cancel();
    });

    group('FullscreenFeedBloc integration', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'receives initial videos from createVideosStream',
        build: () => FullscreenFeedBloc(
          videosStream: createVideosStream(
            currentVideos: [createTestVideo('v1'), createTestVideo('v2')],
          ),
          initialIndex: 0,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedStarted()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having((s) => s.videos.length, 'videos count', 2),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'receives live updates via broadcast controller',
        build: () => FullscreenFeedBloc(
          videosStream: createVideosStream(
            currentVideos: [createTestVideo('v1')],
          ),
          initialIndex: 0,
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 100));
          // Simulate provider state change
          broadcastController.add([
            createTestVideo('v1'),
            createTestVideo('v2'),
            createTestVideo('v3'),
          ]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'initial videos count',
            1,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'updated videos count',
            3,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'onLoadMore triggers callback and isLoadingMore resets on stream update',
        build: () {
          return FullscreenFeedBloc(
            videosStream: createVideosStream(
              currentVideos: [createTestVideo('v1')],
            ),
            initialIndex: 0,
            onLoadMore: () {
              // Simulate provider loading more and emitting updated list
              Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
                if (!broadcastController.isClosed) {
                  broadcastController.add([
                    createTestVideo('v1'),
                    createTestVideo('v2'),
                  ]);
                }
              });
            },
          );
        },
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const FullscreenFeedLoadMoreRequested());
        },
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // Initial videos from stream
          isA<FullscreenFeedState>()
              .having((s) => s.videos.length, 'initial count', 1)
              .having((s) => s.isLoadingMore, 'not loading', false),
          // Load more sets isLoadingMore
          isA<FullscreenFeedState>().having(
            (s) => s.isLoadingMore,
            'loading more',
            true,
          ),
          // Stream update arrives with more videos, isLoadingMore resets
          isA<FullscreenFeedState>()
              .having((s) => s.videos.length, 'updated count', 2)
              .having((s) => s.isLoadingMore, 'loading reset', false),
        ],
      );
    });
  });

  group('Async* BLoC stream pattern (liked/reposts grids)', () {
    // Tests the _createReactiveStream() async* pattern used by
    // profile_liked_grid.dart and profile_reposts_grid.dart.
    // Since those are top-level private functions, we test the equivalent
    // behavior pattern directly.

    /// Equivalent to _createReactiveStream in profile_liked_grid.dart
    Stream<List<VideoEvent>> createReactiveStreamFromBloc(
      ProfileLikedVideosBloc bloc,
      List<VideoEvent> currentVideos,
    ) async* {
      yield currentVideos;
      await for (final state in bloc.stream) {
        yield state.videos;
      }
    }

    late _MockLikesRepository mockLikesRepository;
    late _MockVideosRepository mockVideosRepository;
    late StreamController<Set<String>> likedIdsController;

    const currentUserPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    setUp(() {
      mockLikesRepository = _MockLikesRepository();
      mockVideosRepository = _MockVideosRepository();
      likedIdsController = StreamController<Set<String>>.broadcast();

      when(
        () => mockLikesRepository.watchLikedEventIds(),
      ).thenAnswer((_) => likedIdsController.stream);

      when(
        () => mockLikesRepository.getOrderedLikedEventIds(),
      ).thenAnswer((_) async => []);
    });

    tearDown(() {
      likedIdsController.close();
    });

    ProfileLikedVideosBloc createLikedBloc() => ProfileLikedVideosBloc(
      likesRepository: mockLikesRepository,
      videosRepository: mockVideosRepository,
      currentUserPubkey: currentUserPubkey,
    );

    test('emits current videos immediately', () async {
      final bloc = createLikedBloc();
      final currentVideos = [createTestVideo('v1'), createTestVideo('v2')];

      final stream = createReactiveStreamFromBloc(bloc, currentVideos);
      final first = await stream.first;

      expect(first.length, equals(2));
      expect(first[0].id, equals('v1'));

      await bloc.close();
    });

    test('emits updated videos when BLoC state changes via sync', () async {
      final video1 = createTestVideo('event1');
      final video2 = createTestVideo('event2');

      when(() => mockLikesRepository.syncUserReactions()).thenAnswer(
        (_) async => const LikesSyncResult(
          orderedEventIds: ['event1', 'event2'],
          eventIdToReactionId: {'event1': 'reaction1', 'event2': 'reaction2'},
        ),
      );
      when(
        () => mockVideosRepository.getVideosByIds(
          any(),
          cacheResults: any(named: 'cacheResults'),
        ),
      ).thenAnswer((_) async => [video1, video2]);

      final bloc = createLikedBloc();
      final currentVideos = [createTestVideo('v1')];

      final emissions = <List<VideoEvent>>[];
      final stream = createReactiveStreamFromBloc(bloc, currentVideos);
      final sub = stream.listen(emissions.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Trigger a real state change through the BLoC's sync event
      bloc.add(const ProfileLikedVideosSyncRequested());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // First emission is the current videos (from async* yield)
      expect(emissions.first.length, equals(1));
      // Should have received more emissions from BLoC state changes
      // (syncing -> loading -> success with 2 videos)
      expect(emissions.length, greaterThan(1));
      // Last emission should contain the synced videos
      expect(emissions.last.length, equals(2));

      await sub.cancel();
      await bloc.close();
    });

    test('stream cancels cleanly when subscription is cancelled', () async {
      final bloc = createLikedBloc();
      final currentVideos = [createTestVideo('v1')];

      final stream = createReactiveStreamFromBloc(bloc, currentVideos);
      final sub = stream.listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Cancel should not throw
      await sub.cancel();
      await bloc.close();
    });

    group('FullscreenFeedBloc integration with async* stream', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'receives initial videos from async* BLoC stream',
        build: () {
          final likedBloc = createLikedBloc();
          final currentVideos = [createTestVideo('v1'), createTestVideo('v2')];

          return FullscreenFeedBloc(
            videosStream: createReactiveStreamFromBloc(
              likedBloc,
              currentVideos,
            ),
            initialIndex: 1,
          );
        },
        act: (bloc) => bloc.add(const FullscreenFeedStarted()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having((s) => s.videos.length, 'videos count', 2)
              .having((s) => s.currentIndex, 'index', 1),
        ],
      );
    });
  });

  group('Async* BLoC stream pattern (reposts grid)', () {
    /// Equivalent to _createReactiveStream in profile_reposts_grid.dart
    Stream<List<VideoEvent>> createReactiveStreamFromRepostsBloc(
      ProfileRepostedVideosBloc bloc,
      List<VideoEvent> currentVideos,
    ) async* {
      yield currentVideos;
      await for (final state in bloc.stream) {
        yield state.videos;
      }
    }

    late _MockRepostsRepository mockRepostsRepository;
    late _MockVideosRepository mockVideosRepository;
    late StreamController<Set<String>> repostedIdsController;

    const currentUserPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    setUp(() {
      mockRepostsRepository = _MockRepostsRepository();
      mockVideosRepository = _MockVideosRepository();
      repostedIdsController = StreamController<Set<String>>.broadcast();

      when(
        () => mockRepostsRepository.watchRepostedAddressableIds(),
      ).thenAnswer((_) => repostedIdsController.stream);
    });

    tearDown(() {
      repostedIdsController.close();
    });

    ProfileRepostedVideosBloc createRepostsBloc() => ProfileRepostedVideosBloc(
      repostsRepository: mockRepostsRepository,
      videosRepository: mockVideosRepository,
      currentUserPubkey: currentUserPubkey,
    );

    test('emits current videos immediately', () async {
      final bloc = createRepostsBloc();
      final currentVideos = [createTestVideo('r1'), createTestVideo('r2')];

      final stream = createReactiveStreamFromRepostsBloc(bloc, currentVideos);
      final first = await stream.first;

      expect(first.length, equals(2));
      expect(first[0].id, equals('r1'));

      await bloc.close();
    });

    test('stream cancels cleanly when subscription is cancelled', () async {
      final bloc = createRepostsBloc();
      final currentVideos = [createTestVideo('r1')];

      final stream = createReactiveStreamFromRepostsBloc(bloc, currentVideos);
      final sub = stream.listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
      await bloc.close();
    });

    group('FullscreenFeedBloc integration with reposts async* stream', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'receives initial reposted videos from async* BLoC stream',
        build: () {
          final repostsBloc = createRepostsBloc();
          final currentVideos = [
            createTestVideo('r1'),
            createTestVideo('r2'),
            createTestVideo('r3'),
          ];

          return FullscreenFeedBloc(
            videosStream: createReactiveStreamFromRepostsBloc(
              repostsBloc,
              currentVideos,
            ),
            initialIndex: 2,
          );
        },
        act: (bloc) => bloc.add(const FullscreenFeedStarted()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having((s) => s.videos.length, 'videos count', 3)
              .having((s) => s.currentIndex, 'index', 2),
        ],
      );
    });
  });
}
