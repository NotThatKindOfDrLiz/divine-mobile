// ABOUTME: Tests for profile originals feed provider functionality
// ABOUTME: Verifies that originals feed correctly filters videos and wraps with
// VideoFeedState

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_originals_feed_provider.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';

import 'profile_originals_feed_provider_test.mocks.dart';

@GenerateMocks([VideoEventService])
void main() {
  group('ProfileOriginalsFeedProvider', () {
    late ProviderContainer container;
    late MockVideoEventService mockVideoEventService;

    const testUserId = 'test_user_pubkey_123';

    /// Helper to create a VideoEvent for testing
    VideoEvent createTestVideo({
      required String id,
      required String pubkey,
      required int createdAt,
      bool isRepost = false,
    }) {
      return VideoEvent(
        id: id,
        pubkey: pubkey,
        createdAt: createdAt,
        content: 'Test video $id',
        timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        videoUrl: 'https://example.com/$id.mp4',
        isRepost: isRepost,
      );
    }

    setUp(() {
      mockVideoEventService = MockVideoEventService();

      // Default stub for addListener/removeListener (ChangeNotifier methods)
      when(mockVideoEventService.addListener(any)).thenAnswer((_) {});
      when(mockVideoEventService.removeListener(any)).thenAnswer((_) {});

      // Default stub for video update listeners
      when(mockVideoEventService.addVideoUpdateListener(any)).thenReturn(() {});
      when(mockVideoEventService.addNewVideoListener(any)).thenReturn(() {});
    });

    tearDown(() {
      container.dispose();
      reset(mockVideoEventService);
    });

    test(
      'should return empty VideoFeedState when user has no videos',
      () async {
        // Setup: User has no videos
        when(mockVideoEventService.authorVideos(testUserId)).thenReturn([]);
        when(
          mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
        ).thenAnswer((_) async {});

        container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );

        // Act
        final result = await container.read(
          profileOriginalsFeedProvider(testUserId).future,
        );

        // Assert
        expect(result.videos, isEmpty);
        expect(result.hasMoreContent, isFalse);
        expect(result.isLoadingMore, isFalse);
        expect(result.error, isNull);
      },
    );

    test('should filter out reposts and return only original videos', () async {
      // Setup: Mix of original videos and reposts
      final mixedVideos = [
        createTestVideo(
          id: 'original1',
          pubkey: testUserId,
          createdAt: 1000,
          isRepost: false,
        ),
        createTestVideo(
          id: 'repost1',
          pubkey: testUserId,
          createdAt: 900,
          isRepost: true,
        ),
        createTestVideo(
          id: 'original2',
          pubkey: testUserId,
          createdAt: 800,
          isRepost: false,
        ),
        createTestVideo(
          id: 'repost2',
          pubkey: testUserId,
          createdAt: 700,
          isRepost: true,
        ),
      ];

      when(
        mockVideoEventService.authorVideos(testUserId),
      ).thenReturn(mixedVideos);
      when(
        mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Act
      final result = await container.read(
        profileOriginalsFeedProvider(testUserId).future,
      );

      // Assert: Only originals should be returned
      expect(result.videos.length, equals(2));
      expect(result.videos[0].id, equals('original1'));
      expect(result.videos[1].id, equals('original2'));
      expect(result.videos.every((v) => !v.isRepost), isTrue);
    });

    test('should filter out videos from other users', () async {
      // Setup: Videos from test user and other users
      final mixedAuthorVideos = [
        createTestVideo(
          id: 'user_video1',
          pubkey: testUserId,
          createdAt: 1000,
          isRepost: false,
        ),
        createTestVideo(
          id: 'other_user_video',
          pubkey: 'other_user_pubkey',
          createdAt: 900,
          isRepost: false,
        ),
        createTestVideo(
          id: 'user_video2',
          pubkey: testUserId,
          createdAt: 800,
          isRepost: false,
        ),
      ];

      when(
        mockVideoEventService.authorVideos(testUserId),
      ).thenReturn(mixedAuthorVideos);
      when(
        mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Act
      final result = await container.read(
        profileOriginalsFeedProvider(testUserId).future,
      );

      // Assert: Only videos from testUserId should be returned
      expect(result.videos.length, equals(2));
      expect(result.videos.every((v) => v.pubkey == testUserId), isTrue);
    });

    test('should set hasMoreContent true when 10+ videos returned', () async {
      // Setup: 10 original videos
      final manyVideos = List.generate(
        10,
        (i) => createTestVideo(
          id: 'video$i',
          pubkey: testUserId,
          createdAt: 1000 - i,
          isRepost: false,
        ),
      );

      when(
        mockVideoEventService.authorVideos(testUserId),
      ).thenReturn(manyVideos);
      when(
        mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Act
      final result = await container.read(
        profileOriginalsFeedProvider(testUserId).future,
      );

      // Assert
      expect(result.videos.length, equals(10));
      expect(result.hasMoreContent, isTrue);
    });

    test('should set hasMoreContent false when fewer than 10 videos', () async {
      // Setup: Only 5 original videos
      final fewVideos = List.generate(
        5,
        (i) => createTestVideo(
          id: 'video$i',
          pubkey: testUserId,
          createdAt: 1000 - i,
          isRepost: false,
        ),
      );

      when(
        mockVideoEventService.authorVideos(testUserId),
      ).thenReturn(fewVideos);
      when(
        mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Act
      final result = await container.read(
        profileOriginalsFeedProvider(testUserId).future,
      );

      // Assert
      expect(result.videos.length, equals(5));
      expect(result.hasMoreContent, isFalse);
    });

    test('should include lastUpdated timestamp', () async {
      // Setup
      when(mockVideoEventService.authorVideos(testUserId)).thenReturn([]);
      when(
        mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      final beforeTest = DateTime.now();

      // Act
      final result = await container.read(
        profileOriginalsFeedProvider(testUserId).future,
      );

      // Assert
      expect(result.lastUpdated, isNotNull);
      expect(
        result.lastUpdated!.isAfter(beforeTest) ||
            result.lastUpdated!.isAtSameMomentAs(beforeTest),
        isTrue,
      );
    });

    group('loadMore', () {
      test(
        'should delegate to profileFeedProvider which calls service',
        () async {
          // Setup: Initial videos
          final initialVideos = List.generate(
            10,
            (i) => createTestVideo(
              id: 'video$i',
              pubkey: testUserId,
              createdAt: 1000 - i,
              isRepost: false,
            ),
          );

          when(
            mockVideoEventService.authorVideos(testUserId),
          ).thenReturn(initialVideos);
          when(
            mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
          ).thenAnswer((_) async {});
          when(
            mockVideoEventService.queryHistoricalUserVideos(
              testUserId,
              until: anyNamed('until'),
              limit: anyNamed('limit'),
            ),
          ).thenAnswer((_) async {});

          container = ProviderContainer(
            overrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
            ],
          );

          // Get initial state
          final initialResult = await container.read(
            profileOriginalsFeedProvider(testUserId).future,
          );
          expect(initialResult.hasMoreContent, isTrue);

          // Act: Call loadMore
          await container
              .read(profileOriginalsFeedProvider(testUserId).notifier)
              .loadMore();

          // Assert: The underlying service should have been called
          verify(
            mockVideoEventService.queryHistoricalUserVideos(
              testUserId,
              until: anyNamed('until'),
              limit: anyNamed('limit'),
            ),
          ).called(1);
        },
      );

      test('should not call loadMore when hasMoreContent is false', () async {
        // Setup: Few videos so hasMoreContent is false
        final fewVideos = List.generate(
          3,
          (i) => createTestVideo(
            id: 'video$i',
            pubkey: testUserId,
            createdAt: 1000 - i,
            isRepost: false,
          ),
        );

        when(
          mockVideoEventService.authorVideos(testUserId),
        ).thenReturn(fewVideos);
        when(
          mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
        ).thenAnswer((_) async {});

        container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );

        // Get initial state - hasMoreContent should be false
        final initialResult = await container.read(
          profileOriginalsFeedProvider(testUserId).future,
        );
        expect(initialResult.hasMoreContent, isFalse);

        // Act: Call loadMore
        await container
            .read(profileOriginalsFeedProvider(testUserId).notifier)
            .loadMore();

        // Assert: queryHistoricalUserVideos should NOT be called
        verifyNever(
          mockVideoEventService.queryHistoricalUserVideos(
            testUserId,
            until: anyNamed('until'),
            limit: anyNamed('limit'),
          ),
        );
      });
    });

    group('provider keepAlive', () {
      test(
        'provider should be kept alive (not disposed on listener removal)',
        () async {
          // Setup
          when(mockVideoEventService.authorVideos(testUserId)).thenReturn([]);
          when(
            mockVideoEventService.subscribeToUserVideos(testUserId, limit: 100),
          ).thenAnswer((_) async {});

          container = ProviderContainer(
            overrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
            ],
          );

          // Read the provider to initialize it
          await container.read(profileOriginalsFeedProvider(testUserId).future);

          // The provider has keepAlive: true, so it should persist
          // Verify it's still accessible after initial read
          final result = await container.read(
            profileOriginalsFeedProvider(testUserId).future,
          );
          expect(result, isA<VideoFeedState>());
        },
      );
    });

    group('different user IDs', () {
      test('should create separate providers for different user IDs', () async {
        const userId1 = 'user_1';
        const userId2 = 'user_2';

        final user1Videos = [
          createTestVideo(
            id: 'user1_video',
            pubkey: userId1,
            createdAt: 1000,
            isRepost: false,
          ),
        ];

        final user2Videos = [
          createTestVideo(
            id: 'user2_video1',
            pubkey: userId2,
            createdAt: 900,
            isRepost: false,
          ),
          createTestVideo(
            id: 'user2_video2',
            pubkey: userId2,
            createdAt: 800,
            isRepost: false,
          ),
        ];

        when(
          mockVideoEventService.authorVideos(userId1),
        ).thenReturn(user1Videos);
        when(
          mockVideoEventService.authorVideos(userId2),
        ).thenReturn(user2Videos);
        when(
          mockVideoEventService.subscribeToUserVideos(any, limit: 100),
        ).thenAnswer((_) async {});

        container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );

        // Act
        final result1 = await container.read(
          profileOriginalsFeedProvider(userId1).future,
        );
        final result2 = await container.read(
          profileOriginalsFeedProvider(userId2).future,
        );

        // Assert: Each user should have their own videos
        expect(result1.videos.length, equals(1));
        expect(result1.videos[0].id, equals('user1_video'));

        expect(result2.videos.length, equals(2));
        expect(result2.videos[0].id, equals('user2_video1'));
        expect(result2.videos[1].id, equals('user2_video2'));
      });
    });
  });
}
